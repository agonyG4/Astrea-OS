// ============================================================
//  spotify-visualizer — PipeWire via PulseAudio compat
//
//  cargo build --release                         (Unix socket)
//  cargo build --release --no-default-features \
//              --features ipc-stdout             (stdout/pipe)
// ============================================================

use libpulse_binding::{
    self as pulse,
    context::{Context, FlagSet as ContextFlagSet},
    mainloop::threaded::Mainloop,
    proplist::Proplist,
    sample::{Format, Spec},
    stream::{FlagSet as StreamFlagSet, PeekResult, Stream},
};
use libpulse_simple_binding::Simple;
use rustfft::{num_complex::Complex, FftPlanner};
use serde::Serialize;
use std::{
    sync::{Arc, Mutex},
    thread,
    time::Duration,
};

#[cfg(feature = "ipc-socket")]
use std::{io::Write, os::unix::net::UnixListener, path::Path};

// ----------------------------------------------------------------
const SOCKET_PATH: &str = "/tmp/spotify-visualizer.sock";
const FFT_SIZE:   usize = 2048;
const BANDS:      usize = 32;
const SMOOTH:     f32   = 0.35;
const SAMPLE_RATE: u32  = 44100;

// ----------------------------------------------------------------
#[derive(Serialize, Clone)]
struct Frame {
    bands:  Vec<f32>,
    energy: f32,
}

// ================================================================
// IPC
// ================================================================
enum Output {
    #[cfg(feature = "ipc-socket")]
    Socket { clients: Arc<Mutex<Vec<std::os::unix::net::UnixStream>>> },
    #[cfg(feature = "ipc-stdout")]
    Stdout,
}

impl Output {
    fn send(&self, frame: &Frame) {
        let Ok(json) = serde_json::to_string(frame) else { return };
        let msg = format!("{}\n", json);
        match self {
            #[cfg(feature = "ipc-socket")]
            Output::Socket { clients } => {
                let mut list = clients.lock().unwrap();
                list.retain_mut(|c| c.write_all(msg.as_bytes()).is_ok());
            }
            #[cfg(feature = "ipc-stdout")]
            Output::Stdout => {
                use std::io::Write;
                let _ = std::io::stdout().lock().write_all(msg.as_bytes());
            }
        }
    }
}

#[cfg(feature = "ipc-socket")]
fn start_socket(clients: Arc<Mutex<Vec<std::os::unix::net::UnixStream>>>) {
    if Path::new(SOCKET_PATH).exists() {
        std::fs::remove_file(SOCKET_PATH).ok();
    }
    let listener = UnixListener::bind(SOCKET_PATH)
        .unwrap_or_else(|e| panic!("socket error: {}", e));
    eprintln!("[visualizer] Unix socket em {}", SOCKET_PATH);
    thread::spawn(move || {
        for stream in listener.incoming().flatten() {
            eprintln!("[visualizer] cliente conectado");
            clients.lock().unwrap().push(stream);
        }
    });
}

// ================================================================
// DSP
// ================================================================
fn hann_window(n: usize) -> Vec<f32> {
    use std::f64::consts::PI;
    (0..n)
        .map(|i| (0.5 * (1.0 - (2.0 * PI * i as f64 / (n - 1) as f64).cos())) as f32)
        .collect()
}

fn log_bands(mags: &[f32], n: usize) -> Vec<f32> {
    let res     = SAMPLE_RATE as f32 / FFT_SIZE as f32;
    let log_min = 40_f32.log2();
    let log_max = 16_000_f32.log2();
    let step    = (log_max - log_min) / n as f32;
    (0..n)
        .map(|i| {
            let lo = ((2f32.powf(log_min + i as f32 * step))       / res) as usize;
            let hi = ((2f32.powf(log_min + (i + 1) as f32 * step)) / res) as usize;
            let lo = lo.max(1);
            let hi = hi.min(mags.len() - 1).max(lo + 1);
            mags[lo..hi].iter().copied().sum::<f32>() / (hi - lo) as f32
        })
        .collect()
}

fn smooth_bands(cur: &mut Vec<f32>, tgt: &[f32]) {
    let peak = tgt.iter().cloned().fold(f32::EPSILON, f32::max);
    for (c, &t) in cur.iter_mut().zip(tgt) {
        *c = *c * (1.0 - SMOOTH) + (t / peak) * SMOOTH;
    }
}

// ================================================================
// Acha o sink-input do Spotify via pactl e retorna o monitor
// ================================================================
fn find_spotify_monitor() -> String {
    // PipeWire/PulseAudio cria monitors com o padrão:
    // "spotify.monitor" ou "<sink>.monitor"
    // Usamos pactl para achar o sink onde o Spotify está tocando
    let output = std::process::Command::new("pactl")
        .args(["list", "sink-inputs"])
        .output();

    if let Ok(out) = output {
        let text = String::from_utf8_lossy(&out.stdout).to_lowercase();
        // Acha qual sink o Spotify está usando
        let mut current_sink = String::new();
        for line in text.lines() {
            if line.contains("sink:") {
                // extrai número do sink: "    sink: 0 <..."
                if let Some(n) = line.split_whitespace().nth(1) {
                    current_sink = n.to_string();
                }
            }
            if line.contains("spotify") && !current_sink.is_empty() {
                // Pega o nome do sink via pactl list sinks
                if let Ok(sinks_out) = std::process::Command::new("pactl")
                    .args(["list", "sinks"])
                    .output()
                {
                    let sinks = String::from_utf8_lossy(&sinks_out.stdout);
                    let mut in_sink = false;
                    let mut idx = String::new();
                    for sline in sinks.lines() {
                        if sline.starts_with("Sink #") {
                            idx = sline.trim_start_matches("Sink #").to_string();
                            in_sink = idx == current_sink;
                        }
                        if in_sink && sline.trim().starts_with("Name:") {
                            let name = sline.split(':').nth(1).unwrap_or("").trim().to_string();
                            let monitor = format!("{}.monitor", name);
                            eprintln!("[visualizer] Monitor do Spotify: {}", monitor);
                            return monitor;
                        }
                    }
                }
            }
        }
    }

    // Fallback: monitor do sink padrão
    eprintln!("[visualizer] Spotify não detectado, usando monitor padrão");
    eprintln!("[visualizer] Dica: abra o Spotify e toque algo antes de rodar");
    "@DEFAULT_MONITOR@".to_string()
}

// ================================================================
// Main
// ================================================================
fn main() {
    #[cfg(all(feature = "ipc-socket", not(feature = "ipc-stdout")))]
    let output = {
        let clients = Arc::new(Mutex::new(Vec::<std::os::unix::net::UnixStream>::new()));
        start_socket(clients.clone());
        Arc::new(Output::Socket { clients })
    };
    #[cfg(feature = "ipc-stdout")]
    let output = {
        eprintln!("[visualizer] Modo stdout");
        Arc::new(Output::Stdout)
    };

    let monitor_name = find_spotify_monitor();

    // Spec: F32LE mono 44100Hz
    let spec = Spec {
        format:   Format::F32le,
        rate:     SAMPLE_RATE,
        channels: 1,
    };
    assert!(spec.is_valid());

    // Simple blocking read — mais estável para captura de monitor
    let pa = Simple::new(
        None,                           // servidor padrão (PipeWire)
        "spotify-visualizer",           // nome do app
        pulse::stream::Direction::Record,
        Some(&monitor_name),            // source: monitor do Spotify
        "visualizer",                   // descrição do stream
        &spec,
        None,                           // channel map padrão
        None,                           // buffer attr padrão
    ).unwrap_or_else(|e| {
        eprintln!("[visualizer] Erro ao conectar no PulseAudio/PipeWire: {:?}", e);
        eprintln!("[visualizer] Verifique se o PipeWire está rodando: systemctl --user status pipewire");
        std::process::exit(1);
    });

    eprintln!("[visualizer] Conectado em '{}'", monitor_name);

    // Buffer PCM
    let pcm: Arc<Mutex<Vec<f32>>> = Arc::new(Mutex::new(Vec::new()));

    // Thread FFT
    {
        let pcm_r  = pcm.clone();
        let out    = output.clone();
        let window = hann_window(FFT_SIZE);
        let mut smooth_st = vec![0.0f32; BANDS];
        let mut planner   = FftPlanner::<f32>::new();
        let fft           = planner.plan_fft_forward(FFT_SIZE);

        thread::spawn(move || loop {
            thread::sleep(Duration::from_millis(16));

            let samples: Vec<f32> = {
                let mut b = pcm_r.lock().unwrap();
                if b.len() < FFT_SIZE { continue; }
                b.drain(..FFT_SIZE).collect()
            };

            let mut cx: Vec<Complex<f32>> = samples.iter().zip(window.iter())
                .map(|(&s, &w)| Complex::new(s * w, 0.0))
                .collect();
            fft.process(&mut cx);

            let mags: Vec<f32> = cx[..FFT_SIZE / 2]
                .iter().map(|c| c.norm() / FFT_SIZE as f32).collect();

            let raw    = log_bands(&mags, BANDS);
            let energy = raw.iter().sum::<f32>() / BANDS as f32;
            smooth_bands(&mut smooth_st, &raw);

            out.send(&Frame {
                bands:  smooth_st.clone(),
                energy: energy.clamp(0.0, 1.0),
            });
        });
    }

    // Loop de leitura PCM (blocking, thread principal)
    let mut buf = vec![0u8; FFT_SIZE * 4]; // f32 = 4 bytes, mono
    eprintln!("[visualizer] Rodando. Ctrl+C para sair.");

    loop {
        if pa.read(&mut buf).is_err() {
            eprintln!("[visualizer] Erro de leitura, reconectando...");
            thread::sleep(Duration::from_millis(500));
            continue;
        }

        let samples: Vec<f32> = buf.chunks_exact(4)
            .map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]]))
            .collect();

        let mut b = pcm.lock().unwrap();
        b.extend_from_slice(&samples);
        if b.len() > FFT_SIZE * 8 {
            let excess = b.len() - FFT_SIZE * 8;
            b.drain(..excess);
        }
    }
}