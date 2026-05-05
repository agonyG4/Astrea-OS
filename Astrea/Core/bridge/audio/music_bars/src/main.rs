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
use serde::{Deserialize, Serialize};
use std::{
    path::PathBuf,
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};

#[cfg(feature = "ipc-socket")]
use std::{io::Write, os::unix::net::UnixListener, path::Path};

// ----------------------------------------------------------------
#[cfg(feature = "ipc-socket")]
const FALLBACK_SOCKET_PATH: &str = "/tmp/astrea-music-bars.sock";
const FFT_SIZE:   usize = 2048;
const HOP_SIZE:   usize = FFT_SIZE / 4;
const BANDS:      usize = 16;
const OUTPUT_BANDS: usize = 6;
const DEFAULT_INPUT_GAIN: f32 = 2.15;
const DEFAULT_SENSITIVITY: f32 = 1.0;
const DEFAULT_IDLE_FLOOR: f32 = 0.018;
const DEFAULT_APPLE_SMOOTHNESS: f32 = 0.72;
const DEFAULT_BEAT_STRENGTH: f32 = 1.0;
const PEAK_ATTACK: f32 = 0.30;
const PEAK_RELEASE: f32 = 0.014;
const PEAK_FALL: f32 = 0.008;
const SPRING: f32 = 0.145;
const DAMPING: f32 = 0.74;
const MIN_FREQ:   f32   = 42.0;
const MAX_FREQ:   f32   = 14_500.0;
const SAMPLE_RATE: u32  = 48000;
const CHANNELS:    u8   = 2;
const BEAT_ATTACK: f32 = 0.44;
const BEAT_DECAY: f32 = 0.88;
const SILENCE_GATE: f32 = 0.000_018;
const BAND_GAINS: [f32; BANDS] = [
    0.72, 0.78, 0.86, 0.94,
    1.05, 1.14, 1.18, 1.16,
    1.12, 1.08, 1.04, 1.00,
    0.98, 0.96, 0.94, 0.92,
];

// ----------------------------------------------------------------
#[derive(Serialize, Clone)]
struct Frame {
    bands:  Vec<f32>,
    peaks:  Vec<f32>,
    energy: f32,
}

#[derive(Clone)]
struct MusicBarsConfig {
    input_gain: f32,
    sensitivity: f32,
    idle_floor: f32,
    apple_smoothness: f32,
    beat_strength: f32,
    visual_style: String,
}

#[derive(Deserialize)]
struct PartialMusicBarsConfig {
    input_gain: Option<f32>,
    sensitivity: Option<f32>,
    idle_floor: Option<f32>,
    apple_smoothness: Option<f32>,
    beat_strength: Option<f32>,
    visual_style: Option<String>,
}

impl Default for MusicBarsConfig {
    fn default() -> Self {
        Self {
            input_gain: DEFAULT_INPUT_GAIN,
            sensitivity: DEFAULT_SENSITIVITY,
            idle_floor: DEFAULT_IDLE_FLOOR,
            apple_smoothness: DEFAULT_APPLE_SMOOTHNESS,
            beat_strength: DEFAULT_BEAT_STRENGTH,
            visual_style: "apple_island".to_string(),
        }
    }
}

impl MusicBarsConfig {
    fn load() -> Self {
        let Some(path) = config_path() else {
            return Self::default();
        };

        let Ok(text) = std::fs::read_to_string(&path) else {
            return Self::default();
        };

        let defaults = Self::default();
        let Ok(partial) = serde_json::from_str::<PartialMusicBarsConfig>(&text) else {
            eprintln!(
                "[music-bars] Config inválido em {}; usando defaults",
                path.display()
            );
            return defaults;
        };

        let config = Self {
            input_gain: partial.input_gain.unwrap_or(defaults.input_gain).clamp(0.2, 8.0),
            sensitivity: partial.sensitivity.unwrap_or(defaults.sensitivity).clamp(0.35, 2.5),
            idle_floor: partial.idle_floor.unwrap_or(defaults.idle_floor).clamp(0.0, 0.08),
            apple_smoothness: partial
                .apple_smoothness
                .unwrap_or(defaults.apple_smoothness)
                .clamp(0.0, 1.0),
            beat_strength: partial.beat_strength.unwrap_or(defaults.beat_strength).clamp(0.0, 2.2),
            visual_style: partial.visual_style.unwrap_or(defaults.visual_style),
        };
        eprintln!(
            "[music-bars] Config carregado: gain {:.2}, sens {:.2}, floor {:.3}, smooth {:.2}, beat {:.2}, style {}",
            config.input_gain,
            config.sensitivity,
            config.idle_floor,
            config.apple_smoothness,
            config.beat_strength,
            config.visual_style
        );
        config
    }
}

fn config_path() -> Option<PathBuf> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .map(|home| home.join(".config/AstreaOS/ui/music_bars.json"))
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
fn socket_path() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .map(|dir| dir.join("astrea-music-bars.sock"))
        .unwrap_or_else(|| PathBuf::from(FALLBACK_SOCKET_PATH))
}

#[cfg(feature = "ipc-socket")]
fn start_socket(clients: Arc<Mutex<Vec<std::os::unix::net::UnixStream>>>) {
    let path = socket_path();
    let Ok((listener, bound_path)) = bind_socket(&path).or_else(|first_error| {
        let fallback = PathBuf::from(FALLBACK_SOCKET_PATH);
        eprintln!(
            "[music-bars] Falha ao abrir socket em {}: {}; tentando {}",
            path.display(),
            first_error,
            fallback.display()
        );
        bind_socket(&fallback).map_err(|fallback_error| {
            eprintln!(
                "[music-bars] Socket desativado: {}; fallback {} também falhou: {}",
                first_error,
                fallback.display(),
                fallback_error
            );
            fallback_error
        })
    }) else {
        return;
    };
    eprintln!("[music-bars] Unix socket em {}", bound_path.display());
    thread::spawn(move || {
        for stream in listener.incoming().flatten() {
            eprintln!("[music-bars] cliente conectado");
            clients.lock().unwrap().push(stream);
        }
    });
}

#[cfg(feature = "ipc-socket")]
fn bind_socket(path: &Path) -> std::io::Result<(UnixListener, PathBuf)> {
    if path.exists() {
        std::fs::remove_file(path).ok();
    }
    UnixListener::bind(path).map(|listener| (listener, path.to_path_buf()))
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

        (weighted_sum / weight_total.max(f32::EPSILON)).sqrt().max(0.0)
    }).collect()
}

fn normalize_bands(raw: &[f32], adaptive_peak: &mut f32, config: &MusicBarsConfig) -> (Vec<f32>, f32) {
    let frame_peak = raw.iter().copied().fold(0.0, f32::max) * config.input_gain;
    if frame_peak > *adaptive_peak {
        *adaptive_peak += (frame_peak - *adaptive_peak) * PEAK_ATTACK;
    } else {
        *adaptive_peak += (frame_peak - *adaptive_peak) * PEAK_RELEASE;
    }

    let signal = frame_peak.max(0.0);
    if signal < SILENCE_GATE && *adaptive_peak < SILENCE_GATE * 3.0 {
        return (vec![0.0; BANDS], signal);
    }

    // Hybrid normalization keeps quiet songs alive without letting silence
    // appoint itself as the reference level.
    let peak = (*adaptive_peak * 0.76 + frame_peak * 0.24).max(0.000_001);
    let bands = raw.iter()
        .enumerate()
        .map(|(i, v)| {
            let normalized = (v * config.input_gain / peak * config.sensitivity).max(0.0);
            let t = i as f32 / (BANDS - 1) as f32;
            let exponent = 0.58 + t * 0.15;
            let tuned = normalized.powf(exponent) * BAND_GAINS[i];
            tuned.clamp(0.0, 1.0)
        })
        .collect();

    (bands, signal)
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
    config: MusicBarsConfig,
    target: Vec<f32>,
    rendered: Vec<f32>,
    velocity: Vec<f32>,
    peaks: Vec<f32>,
    adaptive_peak: f32,
    energy: f32,
    beat: f32,
    previous_energy: f32,
    phase: f32,
}

impl VisualState {
    fn new(config: MusicBarsConfig) -> Self {
        Self {
            config,
            target: vec![0.0; BANDS],
            rendered: vec![0.0; OUTPUT_BANDS],
            velocity: vec![0.0; OUTPUT_BANDS],
            peaks: vec![0.0; OUTPUT_BANDS],
            adaptive_peak: 0.000_25,
            energy: 0.0,
            beat: 0.0,
            previous_energy: 0.0,
            phase: 0.0,
        }
    }

    fn ingest(&mut self, raw: &[f32]) {
        let (normalized, signal) = normalize_bands(raw, &mut self.adaptive_peak, &self.config);
        let live_signal = signal > SILENCE_GATE * 2.5;
        for (band, target) in self.target.iter_mut().enumerate() {
            let shaped = if live_signal {
                normalized[band].max(self.config.idle_floor * 0.22)
            } else {
                0.0
            };
            let factor = attack_release(*target, shaped, band);
            *target += (shaped - *target) * factor;
            if !live_signal && *target < 0.001 {
                *target = 0.0;
            }
        }

        let instantaneous_energy = normalized.iter().sum::<f32>() / BANDS as f32;
        let transient = (instantaneous_energy - self.previous_energy).max(0.0);
        if live_signal && transient > 0.052 && instantaneous_energy > 0.085 {
            self.beat = (self.beat + transient * 4.2 * self.config.beat_strength).min(1.0);
        } else {
            self.beat = (self.beat * BEAT_DECAY).max(0.0);
        }
        self.previous_energy += (instantaneous_energy - self.previous_energy) * BEAT_ATTACK;
        let energy_factor = if live_signal { 0.070 } else { 0.045 };
        self.energy += (instantaneous_energy - self.energy) * energy_factor;
        if !live_signal && self.energy < 0.001 {
            self.energy = 0.0;
            self.beat = 0.0;
        }
    }

    fn frame(&mut self) -> Frame {
        self.phase = (self.phase + 0.11) % (std::f32::consts::TAU);

        for index in 0..OUTPUT_BANDS {
            let sampled = self.output_band(index);
            let active = sampled > 0.006 || self.energy > 0.018 || self.beat > 0.001;
            let bass_pulse = (self.output_band(2) + self.output_band(3)) * 0.5;
            let beat_kick = self.beat * (0.12 + bass_pulse * 0.24);
            let flutter = if active {
                (self.phase * (1.05 + index as f32 * 0.13) + index as f32 * 1.37).sin()
                    * (0.014 + self.energy * 0.032)
            } else {
                0.0
            };
            let shimmer = if active {
                (self.phase * 2.15 + index as f32 * 2.11).sin() * 0.016 * self.beat
            } else {
                0.0
            };
            let live_floor = if active && self.energy > 0.045 {
                self.config.idle_floor * (0.22 + self.energy * 0.38)
            } else {
                0.0
            };
            let idle_wiggle = if active && self.energy > 0.045 {
                (self.phase * 0.63 + index as f32 * 1.83).sin().abs() * self.energy * 0.007
            } else {
                0.0
            };

            let target = ((sampled + beat_kick + flutter + idle_wiggle).max(0.0)
                * (1.0 + shimmer))
                .clamp(live_floor, 1.0);
            self.spring_to(index, target, self.config.apple_smoothness);
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

    fn output_band(&self, index: usize) -> f32 {
        let (start, end) = match index {
            0 => (11, 16),
            1 => (6, 11),
            2 => (0, 4),
            3 => (2, 6),
            4 => (6, 11),
            5 => (11, 16),
            _ => return 0.0,
        };

        self.band_average(start, end)
    }

    fn band_average(&self, start: usize, end: usize) -> f32 {
        let start = start.min(BANDS);
        let end = end.min(BANDS);
        if start >= end {
            return 0.0;
        }

        let sum: f32 = self.target[start..end].iter().copied().sum();
        sum / (end - start) as f32
    }

    fn spring_to(&mut self, index: usize, target: f32, release_bias: f32) {
        let current = self.rendered[index];
        let smooth = release_bias.clamp(0.0, 1.0);
        let mut spring = SPRING * (1.18 - smooth * 0.22);
        let mut damping = (DAMPING + smooth * 0.07).min(0.84);

        if target < current {
            spring = (spring * (0.58 + (1.0 - smooth) * 0.18)).max(0.055);
            damping = (damping + smooth * 0.05).min(0.88);
        }

        self.velocity[index] = (self.velocity[index] + (target - current) * spring) * damping;
        self.rendered[index] = (current + self.velocity[index]).clamp(0.0, 1.0);
        if target <= 0.0 && self.rendered[index] < 0.001 {
            self.rendered[index] = 0.0;
            self.velocity[index] = 0.0;
        }
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

fn music_app_score(text: &str) -> u8 {
    let lower = text.to_ascii_lowercase();
    let app_tokens = [
        "spotify",
        "spotify_player",
        "youtube music",
        "youtube-music",
        "tidal",
        "deezer",
        "strawberry",
        "clementine",
        "rhythmbox",
        "lollypop",
        "amberol",
        "audacious",
        "deadbeef",
        "quodlibet",
        "amarok",
        "mpd",
        "mopidy",
    ];

    if app_tokens.iter().any(|token| lower.contains(token)) {
        100
    } else if lower.contains("media.role = \"music\"")
        || lower.contains("application.category = \"music\"")
    {
        70
    } else {
        0
    }
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

        score = score.max(music_app_score(line));
    }

    if corked {
        score = score.saturating_sub(20);
    }

    sink.map(|sink| (score, sink)).filter(|(score, _)| *score > 0)
}

fn find_music_monitor() -> Option<String> {
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
                return Some(monitor);
            }
        }
    }

    eprintln!("[music-bars] Nenhum app de música detectado; aguardando player");
    None
}

fn connect_monitor(monitor_name: &str) -> Option<Simple> {
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

    Simple::new(
        None,                           // servidor padrão (PipeWire)
        "astrea-music-bars",            // nome do app
        pulse::stream::Direction::Record,
        Some(monitor_name),             // source: monitor do player de música
        "music bars",                   // descrição do stream
        &spec,
        None,                           // channel map padrão
        Some(&buffer_attr),             // baixa latência para o music bars
    ).map_err(|e| {
        eprintln!("[music-bars] Erro ao conectar em '{}': {:?}", monitor_name, e);
        e
    }).ok()
}

fn push_samples(pcm: &Arc<Mutex<Vec<f32>>>, samples: &[f32]) {
    let mut b = pcm.lock().unwrap();
    b.extend_from_slice(samples);
    if b.len() > FFT_SIZE * 4 {
        let excess = b.len() - FFT_SIZE * 4;
        b.drain(..excess);
    }
}

// ================================================================
// Main
// ================================================================
fn main() {
    let config = MusicBarsConfig::load();

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

    // Buffer PCM
    let pcm: Arc<Mutex<Vec<f32>>> = Arc::new(Mutex::new(Vec::new()));

    // Thread FFT
    {
        let pcm_r  = pcm.clone();
        let out    = output.clone();
        let window = hann_window(FFT_SIZE);
        let mut visual = VisualState::new(config.clone());
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
        let Some(monitor_name) = find_music_monitor() else {
            push_samples(&pcm, &vec![0.0; HOP_SIZE]);
            thread::sleep(Duration::from_millis(900));
            continue;
        };

        let Some(pa) = connect_monitor(&monitor_name) else {
            push_samples(&pcm, &vec![0.0; HOP_SIZE]);
            thread::sleep(Duration::from_millis(900));
            continue;
        };

        eprintln!("[music-bars] Conectado em '{}'", monitor_name);
        let mut next_player_check = Instant::now() + Duration::from_millis(850);

        loop {
            if pa.read(&mut buf).is_err() {
                eprintln!("[music-bars] Erro de leitura, reconectando...");
                thread::sleep(Duration::from_millis(500));
                break;
            }

            if Instant::now() >= next_player_check {
                next_player_check = Instant::now() + Duration::from_millis(850);
                if find_music_monitor().as_deref() != Some(monitor_name.as_str()) {
                    eprintln!("[music-bars] Player de música saiu/trocou; revalidando fonte");
                    push_samples(&pcm, &vec![0.0; HOP_SIZE]);
                    break;
                }
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

            push_samples(&pcm, &samples);
        }
    }
}
