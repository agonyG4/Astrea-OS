// ============================================================
//  music-bars — PipeWire via PulseAudio compat
//
//  cargo build --release                         (Unix socket)
//  cargo build --release --no-default-features \
//              --features ipc-stdout             (stdout/pipe)
// ============================================================

use libpulse_binding::{
    self as pulse,
    def::BufferAttr,
    sample::{Format, Spec},
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
#[cfg(feature = "ipc-socket")]
const SOCKET_PATH: &str = "/tmp/astrea-music-bars.sock";
const FFT_SIZE:   usize = 2048;
const HOP_SIZE:   usize = FFT_SIZE / 4;
const BANDS:      usize = 16;
const OUTPUT_BANDS: usize = 6;
const INPUT_GAIN: f32   = 2.15;
const PEAK_ATTACK: f32  = 0.36;
const PEAK_RELEASE: f32 = 0.010;
const PEAK_FALL:  f32   = 0.010;
const SPRING:     f32   = 0.18;
const DAMPING:    f32   = 0.68;
const IDLE_FLOOR: f32   = 0.018;
const MIN_FREQ:   f32   = 42.0;
const MAX_FREQ:   f32   = 14_500.0;
const SAMPLE_RATE: u32  = 48000;
const CHANNELS:    u8   = 2;
const OUTPUT_GAINS: [f32; OUTPUT_BANDS] = [0.96, 1.02, 1.12, 1.32, 1.62, 2.05];
const BAND_GAINS: [f32; BANDS] = [
    1.34, 1.28, 1.18, 1.10,
    1.04, 1.00, 1.02, 1.04,
    1.02, 0.99, 0.95, 0.91,
    0.86, 0.80, 0.74, 0.68,
];

// ----------------------------------------------------------------
#[derive(Serialize, Clone)]
struct Frame {
    bands:  Vec<f32>,
    peaks:  Vec<f32>,
    energy: f32,
}

// ================================================================
// IPC
// ================================================================
enum Output {
    #[cfg(feature = "ipc-socket")]
    #[allow(dead_code)]
    Socket { clients: Arc<Mutex<Vec<std::os::unix::net::UnixStream>>> },
    #[cfg(feature = "ipc-stdout")]
    #[allow(dead_code)]
    Stdout,
    #[cfg(all(feature = "ipc-socket", feature = "ipc-stdout"))]
    Both { clients: Arc<Mutex<Vec<std::os::unix::net::UnixStream>>> },
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
            #[cfg(all(feature = "ipc-socket", feature = "ipc-stdout"))]
            Output::Both { clients } => {
                {
                    let mut list = clients.lock().unwrap();
                    list.retain_mut(|c| c.write_all(msg.as_bytes()).is_ok());
                }
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
    eprintln!("[music-bars] Unix socket em {}", SOCKET_PATH);
    thread::spawn(move || {
        for stream in listener.incoming().flatten() {
            eprintln!("[music-bars] cliente conectado");
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

fn band_center(index: usize) -> f32 {
    let t = index as f32 / (BANDS - 1) as f32;
    MIN_FREQ * (MAX_FREQ / MIN_FREQ).powf(t)
}

fn band_width(index: usize) -> f32 {
    let prev = if index == 0 { MIN_FREQ.log2() } else { band_center(index - 1).log2() };
    let next = if index + 1 == BANDS { MAX_FREQ.log2() } else { band_center(index + 1).log2() };
    ((next - prev) * 0.56).max(0.08)
}

fn log_bands(mags: &[f32]) -> Vec<f32> {
    let bin_hz = SAMPLE_RATE as f32 / FFT_SIZE as f32;
    (0..BANDS).map(|band| {
        let center = band_center(band).log2();
        let width = band_width(band);
        let mut weighted_sum = 0.0;
        let mut weight_total = 0.0;

        for (bin, mag) in mags.iter().enumerate().skip(1) {
            let freq = bin as f32 * bin_hz;
            if !(MIN_FREQ..=MAX_FREQ).contains(&freq) {
                continue;
            }

            let distance = ((freq.log2() - center) / width).abs();
            if distance >= 1.25 {
                continue;
            }

            let weight = (1.0 - distance / 1.25).powf(2.0);
            weighted_sum += mag * mag * weight;
            weight_total += weight;
        }

        let rms = (weighted_sum / weight_total.max(f32::EPSILON)).sqrt();
        (rms * BAND_GAINS[band]).max(0.0)
    }).collect()
}

fn normalize_bands(raw: &[f32], adaptive_peak: &mut f32) -> Vec<f32> {
    let frame_peak = raw.iter().copied().fold(0.0, f32::max) * INPUT_GAIN;
    if frame_peak > *adaptive_peak {
        *adaptive_peak += (frame_peak - *adaptive_peak) * PEAK_ATTACK;
    } else {
        *adaptive_peak += (frame_peak - *adaptive_peak) * PEAK_RELEASE;
    }

    // Normalize each frame against its own peak.
    // Keep that behavior so quiet PipeWire monitor captures still produce motion.
    let peak = frame_peak.max(0.000_000_001);
    raw.iter()
        .enumerate()
        .map(|(i, v)| {
            let normalized = (v * INPUT_GAIN / peak).max(0.0);
            let t = i as f32 / (BANDS - 1) as f32;
            let exponent = 0.60 + t * 0.13;
            let tuned = normalized.powf(exponent) * BAND_GAINS[i];
            tuned.clamp(0.0, 1.0)
        })
        .collect()
}

fn attack_release(current: f32, target: f32, band: usize) -> f32 {
    let t = band as f32 / (BANDS - 1) as f32;
    let delta = (target - current).abs();

    if target > current {
        (0.42 + delta * 0.28 + t * 0.05).min(0.82)
    } else {
        (0.070 + delta * 0.045 + t * 0.065).min(0.20)
    }
}

struct VisualState {
    target: Vec<f32>,
    rendered: Vec<f32>,
    velocity: Vec<f32>,
    peaks: Vec<f32>,
    adaptive_peak: f32,
    energy: f32,
    phase: f32,
}

impl VisualState {
    fn new() -> Self {
        Self {
            target: vec![0.0; BANDS],
            rendered: vec![0.0; OUTPUT_BANDS],
            velocity: vec![0.0; OUTPUT_BANDS],
            peaks: vec![0.0; OUTPUT_BANDS],
            adaptive_peak: 0.000_25,
            energy: 0.0,
            phase: 0.0,
        }
    }

    fn ingest(&mut self, raw: &[f32]) {
        let normalized = normalize_bands(raw, &mut self.adaptive_peak);
        for (band, target) in self.target.iter_mut().enumerate() {
            let shaped = normalized[band].max(IDLE_FLOOR * 0.45);
            let factor = attack_release(*target, shaped, band);
            *target += (shaped - *target) * factor;
        }

        let instantaneous_energy = normalized.iter().sum::<f32>() / BANDS as f32;
        self.energy += (instantaneous_energy - self.energy) * 0.075;
    }

    fn frame(&mut self) -> Frame {
        self.phase = (self.phase + 0.11) % (std::f32::consts::TAU);

        for index in 0..OUTPUT_BANDS {
            let pos = index as f32 * (BANDS - 1) as f32 / (OUTPUT_BANDS - 1) as f32;
            let lo = pos.floor() as usize;
            let hi = (lo + 1).min(BANDS - 1);
            let mix = pos - lo as f32;
            let sampled = self.target[lo] + (self.target[hi] - self.target[lo]) * mix;
            let band_t = pos / (BANDS - 1) as f32;
            let shared_energy = self.energy * (0.05 + band_t * 0.18);
            let base = (sampled.max(shared_energy) * OUTPUT_GAINS[index]).clamp(0.0, 1.0);
            let breath = (self.phase + index as f32 * 0.57).sin() * IDLE_FLOOR * 0.35;
            let shimmer = (self.phase * 1.73 + index as f32 * 1.91).sin() * 0.018 * self.energy;
            let low_decay_bias = (1.0 - band_t) * 0.016;
            let asymmetry = 1.0 + ((self.phase * 0.37 + index as f32 * 1.29).sin() * 0.018);

            let target = (base * asymmetry * (1.0 + shimmer) + breath).max(IDLE_FLOOR * 0.32);
            self.spring_to(index, target, low_decay_bias);
        }

        for (peak, &value) in self.peaks.iter_mut().zip(&self.rendered) {
            if value > *peak {
                *peak = value;
            } else {
                *peak = (*peak - PEAK_FALL).max(value * 0.78).max(0.0);
            }
        }

        Frame {
            bands: self.rendered.clone(),
            peaks: self.peaks.clone(),
            energy: self.energy.clamp(0.0, 1.0),
        }
    }

    fn spring_to(&mut self, index: usize, target: f32, release_bias: f32) {
        let current = self.rendered[index];
        let mut spring = SPRING;
        let mut damping = DAMPING;

        if target < current {
            spring = (spring * (0.72 - release_bias)).max(0.09);
            damping = (damping + release_bias).min(0.78);
        }

        self.velocity[index] = (self.velocity[index] + (target - current) * spring) * damping;
        self.rendered[index] = (current + self.velocity[index]).clamp(0.0, 1.0);
    }
}

// ================================================================
// Resolve o stream de música e retorna o monitor do sink dele
// ================================================================
fn line_value<'a>(line: &'a str, prefix: &str) -> Option<&'a str> {
    line.trim().strip_prefix(prefix).map(str::trim)
}

fn sink_monitor_name(sink_id: &str) -> Option<String> {
    let out = std::process::Command::new("pactl")
        .args(["list", "sinks"])
        .output()
        .ok()?;

    let sinks = String::from_utf8_lossy(&out.stdout);
    let mut in_sink = false;
    let mut fallback_name = None;

    for line in sinks.lines() {
        if let Some(id) = line.strip_prefix("Sink #") {
            in_sink = id.trim() == sink_id;
            fallback_name = None;
            continue;
        }

        if !in_sink {
            continue;
        }

        if let Some(source) = line_value(line, "Monitor Source:") {
            return Some(source.to_string());
        }

        if let Some(name) = line_value(line, "Name:") {
            fallback_name = Some(format!("{}.monitor", name));
        }
    }

    fallback_name
}

fn sink_input_score(block: &str) -> Option<(u8, String)> {
    let mut sink = None;
    let mut corked = false;
    let mut score = 0u8;

    for line in block.lines() {
        if let Some(value) = line_value(line, "Sink:") {
            sink = value.split_whitespace().next().map(str::to_string);
        } else if let Some(value) = line_value(line, "Corked:") {
            corked = value.eq_ignore_ascii_case("yes");
        }

        let lower = line.to_ascii_lowercase();
        if lower.contains("spotify") || lower.contains("spotify_player") {
            score = score.max(100);
        } else if lower.contains("media.role = \"music\"")
            || lower.contains("application.category = \"music\"")
        {
            score = score.max(70);
        } else if lower.contains("media.category = \"playback\"") {
            score = score.max(40);
        }
    }

    if corked {
        score = score.saturating_sub(20);
    }

    sink.map(|sink| (score, sink)).filter(|(score, _)| *score > 0)
}

fn find_music_monitor() -> String {
    let output = std::process::Command::new("pactl")
        .args(["list", "sink-inputs"])
        .output();

    if let Ok(out) = output {
        let text = String::from_utf8_lossy(&out.stdout);
        let best = text
            .split("\nSink Input #")
            .filter_map(sink_input_score)
            .max_by_key(|(score, _)| *score);

        if let Some((score, sink_id)) = best {
            if let Some(monitor) = sink_monitor_name(&sink_id) {
                eprintln!(
                    "[music-bars] Stream de música detectado no sink {} (score {}): {}",
                    sink_id, score, monitor
                );
                return monitor;
            }
        }
    }

    eprintln!("[music-bars] Stream de música não detectado, usando monitor padrão");
    eprintln!("[music-bars] Dica: toque algo no player antes de iniciar o music bars");
    "@DEFAULT_MONITOR@".to_string()
}

// ================================================================
// Main
// ================================================================
fn main() {
    #[cfg(all(feature = "ipc-socket", feature = "ipc-stdout"))]
    let output = {
        let clients = Arc::new(Mutex::new(Vec::<std::os::unix::net::UnixStream>::new()));
        start_socket(clients.clone());
        eprintln!("[music-bars] Modo socket + stdout");
        Arc::new(Output::Both { clients })
    };
    #[cfg(all(feature = "ipc-socket", not(feature = "ipc-stdout")))]
    let output = {
        let clients = Arc::new(Mutex::new(Vec::<std::os::unix::net::UnixStream>::new()));
        start_socket(clients.clone());
        Arc::new(Output::Socket { clients })
    };
    #[cfg(all(feature = "ipc-stdout", not(feature = "ipc-socket")))]
    let output = {
        eprintln!("[music-bars] Modo stdout");
        Arc::new(Output::Stdout)
    };

    let monitor_name = find_music_monitor();

    // Match the PipeWire/Pulse default sink format and mix to mono ourselves.
    let spec = Spec {
        format:   Format::F32le,
        rate:     SAMPLE_RATE,
        channels: CHANNELS,
    };
    assert!(spec.is_valid());
    let buffer_attr = BufferAttr {
        maxlength: u32::MAX,
        tlength: u32::MAX,
        prebuf: u32::MAX,
        minreq: u32::MAX,
        fragsize: (HOP_SIZE * 4 * CHANNELS as usize) as u32,
    };

    // Simple blocking read — mais estável para captura de monitor
    let pa = Simple::new(
        None,                           // servidor padrão (PipeWire)
        "astrea-music-bars",            // nome do app
        pulse::stream::Direction::Record,
        Some(&monitor_name),            // source: monitor do Spotify
        "music bars",                   // descrição do stream
        &spec,
        None,                           // channel map padrão
        Some(&buffer_attr),              // baixa latência para o music bars
    ).unwrap_or_else(|e| {
        eprintln!("[music-bars] Erro ao conectar no PulseAudio/PipeWire: {:?}", e);
        eprintln!("[music-bars] Verifique se o PipeWire está rodando: systemctl --user status pipewire");
        std::process::exit(1);
    });

    eprintln!("[music-bars] Conectado em '{}'", monitor_name);

    // Buffer PCM
    let pcm: Arc<Mutex<Vec<f32>>> = Arc::new(Mutex::new(Vec::new()));

    // Thread FFT
    {
        let pcm_r  = pcm.clone();
        let out    = output.clone();
        let window = hann_window(FFT_SIZE);
        let mut visual = VisualState::new();
        let mut planner   = FftPlanner::<f32>::new();
        let fft           = planner.plan_fft_forward(FFT_SIZE);

        thread::spawn(move || loop {
            thread::sleep(Duration::from_millis(8));

            let samples = {
                let mut b = pcm_r.lock().unwrap();
                if b.len() >= FFT_SIZE {
                    let samples = b[..FFT_SIZE].to_vec();
                    b.drain(..HOP_SIZE);
                    Some(samples)
                } else {
                    None
                }
            };

            if let Some(samples) = samples {
                let mut cx: Vec<Complex<f32>> = samples.iter().zip(window.iter())
                    .map(|(&s, &w)| Complex::new(s * w, 0.0))
                    .collect();
                fft.process(&mut cx);

                let mags: Vec<f32> = cx[..FFT_SIZE / 2]
                    .iter().map(|c| c.norm() / FFT_SIZE as f32).collect();

                let raw = log_bands(&mags);
                visual.ingest(&raw);
            }

            out.send(&visual.frame());
        });
    }

    // Loop de leitura PCM (blocking, thread principal)
    let mut buf = vec![0u8; HOP_SIZE * 4 * CHANNELS as usize]; // f32 = 4 bytes
    eprintln!("[music-bars] Rodando. Ctrl+C para sair.");

    loop {
        if pa.read(&mut buf).is_err() {
            eprintln!("[music-bars] Erro de leitura, reconectando...");
            thread::sleep(Duration::from_millis(500));
            continue;
        }

        let samples: Vec<f32> = buf.chunks_exact(4 * CHANNELS as usize)
            .map(|frame| {
                let sum: f32 = frame
                    .chunks_exact(4)
                    .map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]]))
                    .sum();
                sum / CHANNELS as f32
            })
            .collect();

        let mut b = pcm.lock().unwrap();
        b.extend_from_slice(&samples);
        if b.len() > FFT_SIZE * 4 {
            let excess = b.len() - FFT_SIZE * 4;
            b.drain(..excess);
        }
    }
}
