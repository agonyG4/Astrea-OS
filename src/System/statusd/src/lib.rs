use serde::Serialize;
use serde_json::{Value, json};
use signal_hook::consts::signal::{SIGINT, SIGTERM, SIGUSR1};
use signal_hook::iterator::Signals;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const REFRESH_AUDIO: Duration = Duration::from_secs(10);
const REFRESH_NETWORK: Duration = Duration::from_secs(2);
const REFRESH_BLUETOOTH: Duration = Duration::from_secs(45);
const REFRESH_HEALTH: Duration = Duration::from_secs(300);
const AUTOCONNECT: Duration = Duration::from_secs(120);
const MAX_SLEEP: Duration = Duration::from_secs(5);
const COMMAND_CACHE: Duration = Duration::from_secs(300);
const NETWORK_ROUTE_CACHE: Duration = Duration::from_secs(30);
const WIFI_SSID_CACHE: Duration = Duration::from_secs(30);

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct AudioStatus {
    pub ok: bool,
    pub level: i32,
    pub muted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub degraded: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone)]
struct CommandResult {
    ok: bool,
    stdout: String,
    stderr: String,
}

#[derive(Debug, Clone)]
struct NetworkSample {
    at: Instant,
    rx: u64,
    tx: u64,
}

#[derive(Debug)]
pub struct StatusDaemon {
    astrea_root: PathBuf,
    state_dir: PathBuf,
    command_cache: HashMap<String, (Instant, bool)>,
    json_cache: HashMap<PathBuf, String>,
    network_samples: HashMap<String, NetworkSample>,
    route_iface: String,
    route_checked_at: Option<Instant>,
    wifi_ssid_cache: HashMap<String, (Instant, String)>,
    autoconnect_running: Arc<AtomicBool>,
}

impl Default for StatusDaemon {
    fn default() -> Self {
        Self::new()
    }
}

impl StatusDaemon {
    pub fn new() -> Self {
        let home = home_dir();
        let astrea_root = env::var_os("ASTREA_ROOT")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/share/Astrea"));
        let state_home = env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/state"));
        Self {
            astrea_root,
            state_dir: state_home.join("Astrea/status"),
            command_cache: HashMap::new(),
            json_cache: HashMap::new(),
            network_samples: HashMap::new(),
            route_iface: String::new(),
            route_checked_at: None,
            wifi_ssid_cache: HashMap::new(),
            autoconnect_running: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn run(&mut self) -> Result<(), String> {
        let running = Arc::new(AtomicBool::new(true));
        let refresh_requested = Arc::new(AtomicBool::new(false));
        let mut signals = Signals::new([SIGTERM, SIGINT, SIGUSR1])
            .map_err(|err| format!("register signals: {err}"))?;
        let signal_running = Arc::clone(&running);
        let signal_refresh = Arc::clone(&refresh_requested);
        thread::spawn(move || {
            for signal in signals.forever() {
                match signal {
                    SIGUSR1 => signal_refresh.store(true, Ordering::Relaxed),
                    SIGTERM | SIGINT => {
                        signal_running.store(false, Ordering::Relaxed);
                        break;
                    }
                    _ => {}
                }
            }
        });

        let mut next_audio = Instant::now();
        let mut next_network = next_audio;
        let mut next_bluetooth = next_audio;
        let mut next_health = next_audio;
        let mut next_autoconnect = next_audio;
        let mut bluetooth_powered = false;

        while running.load(Ordering::Relaxed) {
            let now = Instant::now();
            if refresh_requested.swap(false, Ordering::Relaxed) {
                next_audio = now;
                next_network = now;
                next_bluetooth = now;
                next_health = now;
                self.route_checked_at = None;
            }

            if now >= next_audio {
                let path = self.audio_path();
                let payload = self.audio_status();
                self.write_json_if_changed(&path, &payload)?;
                next_audio = now + REFRESH_AUDIO;
            }

            if now >= next_health {
                let path = self.health_path();
                let payload = self.health_payload();
                self.write_json_if_changed(&path, &payload)?;
                next_health = now + REFRESH_HEALTH;
            }

            if now >= next_network {
                let path = self.network_path();
                let payload = self.network_status();
                self.write_json_if_changed(&path, &payload)?;
                next_network = now + REFRESH_NETWORK;
            }

            if now >= next_bluetooth {
                let payload = self.bluetooth_status();
                bluetooth_powered = payload
                    .get("powered")
                    .and_then(Value::as_bool)
                    .unwrap_or(false);
                self.write_json_if_changed(&self.bluetooth_path(), &payload)?;
                next_bluetooth = now + REFRESH_BLUETOOTH;
            }

            if now >= next_autoconnect {
                if bluetooth_powered && self.request_bluetooth_autoconnect() {
                    next_bluetooth = next_bluetooth.min(now + Duration::from_secs(5));
                }
                next_autoconnect = now + AUTOCONNECT;
            }

            let next_due = [
                next_audio,
                next_network,
                next_bluetooth,
                next_health,
                next_autoconnect,
            ]
            .into_iter()
            .min()
            .unwrap_or_else(Instant::now);
            let sleep_for = next_due.saturating_duration_since(Instant::now());
            thread::sleep(sleep_for.clamp(Duration::from_millis(200), MAX_SLEEP));
        }
        Ok(())
    }

    fn audio_path(&self) -> PathBuf {
        self.state_dir.join("audio.json")
    }

    fn network_path(&self) -> PathBuf {
        self.state_dir.join("network.json")
    }

    fn bluetooth_path(&self) -> PathBuf {
        self.state_dir.join("bluetooth.json")
    }

    fn health_path(&self) -> PathBuf {
        self.state_dir.join("health.json")
    }

    fn bluetooth_helper(&self) -> PathBuf {
        self.astrea_root.join("System/scripts/bluetooth_manager.py")
    }

    fn write_json_if_changed<T: Serialize>(
        &mut self,
        path: &Path,
        payload: &T,
    ) -> Result<(), String> {
        fs::create_dir_all(&self.state_dir).map_err(|err| format!("create status dir: {err}"))?;
        let data =
            serde_json::to_string(payload).map_err(|err| format!("serialize json: {err}"))? + "\n";
        if self
            .json_cache
            .get(path)
            .is_some_and(|cached| cached == &data)
            && path.exists()
        {
            return Ok(());
        }
        if path.exists() {
            if let Ok(existing) = fs::read_to_string(path) {
                if existing == data {
                    self.json_cache.insert(path.to_path_buf(), data);
                    return Ok(());
                }
            }
        }
        let tmp = path.with_file_name(format!(
            ".{}.tmp",
            path.file_name()
                .and_then(|name| name.to_str())
                .unwrap_or("status")
        ));
        fs::write(&tmp, &data).map_err(|err| format!("write status temp file: {err}"))?;
        fs::rename(&tmp, path).map_err(|err| format!("replace status file: {err}"))?;
        self.json_cache.insert(path.to_path_buf(), data);
        Ok(())
    }

    fn command_available(&mut self, name: &str) -> bool {
        let now = Instant::now();
        if let Some((checked_at, available)) = self.command_cache.get(name) {
            if now.duration_since(*checked_at) < COMMAND_CACHE {
                return *available;
            }
        }
        let available = command_exists(name);
        self.command_cache
            .insert(name.to_string(), (now, available));
        available
    }

    fn run_cmd(&mut self, args: &[&str], timeout: Duration) -> CommandResult {
        if args.is_empty() || !self.command_available(args[0]) {
            return CommandResult {
                ok: false,
                stdout: String::new(),
                stderr: format!(
                    "Missing dependency: {}",
                    args.first().copied().unwrap_or("")
                ),
            };
        }
        run_command(args, timeout)
    }

    fn audio_status(&mut self) -> AudioStatus {
        if !self.command_available("wpctl") {
            return AudioStatus {
                ok: false,
                level: 0,
                muted: false,
                degraded: Some(true),
                error: Some("dependency_missing".to_string()),
            };
        }
        let result = self.run_cmd(
            &["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            Duration::from_secs(3),
        );
        parse_wpctl_volume(&result.stdout, result.ok, &result.stderr)
    }

    fn network_status(&mut self) -> Value {
        if !self.command_available("ip") {
            return dependency_payload(
                "ip",
                "dependency_missing",
                json!({
                    "connected": false,
                    "type": "none",
                    "ssid": "",
                    "download": "0 B/s",
                    "upload": "0 B/s"
                }),
            );
        }

        let iface = self.active_network_iface();
        if iface.is_empty() || !Path::new("/sys/class/net").join(&iface).exists() {
            return json!({
                "connected": false,
                "type": "none",
                "ssid": "",
                "download": "0 B/s",
                "upload": "0 B/s"
            });
        }

        let iface_path = Path::new("/sys/class/net").join(&iface);
        let (network_type, ssid) = if iface_path.join("wireless").exists() {
            ("wifi", self.wifi_ssid_for_iface(&iface))
        } else {
            ("wired", "Ethernet".to_string())
        };
        let (download, upload) = self.interface_rates(&iface);
        json!({
            "connected": true,
            "type": network_type,
            "ssid": ssid,
            "download": download,
            "upload": upload
        })
    }

    fn active_network_iface(&mut self) -> String {
        let now = Instant::now();
        if self
            .route_checked_at
            .is_some_and(|checked| now.duration_since(checked) < NETWORK_ROUTE_CACHE)
        {
            return self.route_iface.clone();
        }

        let iface = fs::read_to_string("/proc/net/route")
            .ok()
            .and_then(|route| default_route_iface_from_proc(&route))
            .or_else(|| {
                let output =
                    self.run_cmd(&["ip", "route", "get", "1.1.1.1"], Duration::from_secs(3));
                parse_route_get_iface(&output.stdout)
            })
            .unwrap_or_default();

        self.route_iface = iface.clone();
        self.route_checked_at = Some(now);
        iface
    }

    fn wifi_ssid_for_iface(&mut self, iface: &str) -> String {
        let now = Instant::now();
        if let Some((checked, ssid)) = self.wifi_ssid_cache.get(iface) {
            if now.duration_since(*checked) < WIFI_SSID_CACHE {
                return ssid.clone();
            }
        }
        let ssid = if self.command_available("nmcli") {
            let output = self.run_cmd(
                &[
                    "nmcli",
                    "-t",
                    "-g",
                    "GENERAL.CONNECTION",
                    "device",
                    "show",
                    iface,
                ],
                Duration::from_secs(3),
            );
            output
                .stdout
                .lines()
                .next()
                .unwrap_or("")
                .trim()
                .to_string()
        } else {
            String::new()
        };
        self.wifi_ssid_cache
            .insert(iface.to_string(), (now, ssid.clone()));
        ssid
    }

    fn interface_rates(&mut self, iface: &str) -> (String, String) {
        let Some((rx, tx)) = interface_counters(iface) else {
            return ("0 B/s".to_string(), "0 B/s".to_string());
        };
        let now = Instant::now();
        let previous = self
            .network_samples
            .insert(iface.to_string(), NetworkSample { at: now, rx, tx });
        let Some(previous) = previous else {
            return ("0 B/s".to_string(), "0 B/s".to_string());
        };
        let elapsed = now.duration_since(previous.at).as_secs_f64().max(0.001);
        (
            format_rate((rx.saturating_sub(previous.rx)) as f64 / elapsed),
            format_rate((tx.saturating_sub(previous.tx)) as f64 / elapsed),
        )
    }

    fn bluetooth_status(&mut self) -> Value {
        let helper = self.bluetooth_helper();
        if !self.command_available("python3") {
            return dependency_payload("python3", "dependency_missing", bluetooth_defaults());
        }
        if !helper.exists() {
            return dependency_payload(
                helper.to_string_lossy().as_ref(),
                "helper_missing",
                bluetooth_defaults(),
            );
        }
        let helper = helper.to_string_lossy().to_string();
        let output = self.run_cmd(&["python3", &helper, "status"], Duration::from_secs(8));
        let mut payload =
            serde_json::from_str::<Value>(&output.stdout).unwrap_or_else(|_| json!({}));
        ensure_bluetooth_defaults(&mut payload);
        if let Some(object) = payload.as_object_mut() {
            object.insert("ok".to_string(), Value::Bool(output.ok));
            if !output.ok && !output.stderr.trim().is_empty() {
                object.insert(
                    "error".to_string(),
                    Value::String(output.stderr.trim().to_string()),
                );
            }
        }
        payload
    }

    fn health_payload(&mut self) -> Value {
        let bluetooth_helper = self.bluetooth_helper().exists();
        let deps = json!({
            "wpctl": self.command_available("wpctl"),
            "ip": self.command_available("ip"),
            "nmcli": self.command_available("nmcli"),
            "python3": self.command_available("python3"),
            "bluetooth_helper": bluetooth_helper,
        });
        let ok = deps.as_object().is_some_and(|object| {
            object
                .values()
                .all(|value| value.as_bool().unwrap_or(false))
        });
        json!({
            "ok": ok,
            "degraded": !ok,
            "dependencies": deps,
            "updated_at": unix_timestamp(),
        })
    }

    fn request_bluetooth_autoconnect(&mut self) -> bool {
        if self
            .autoconnect_running
            .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
            .is_err()
        {
            return false;
        }
        let running = Arc::clone(&self.autoconnect_running);
        let helper = self.bluetooth_helper();
        let python_available = self.command_available("python3");
        thread::spawn(move || {
            if python_available && helper.exists() {
                let helper = helper.to_string_lossy().to_string();
                let _ = run_command(
                    &["python3", &helper, "autoconnect"],
                    Duration::from_secs(20),
                );
            }
            running.store(false, Ordering::Release);
        });
        true
    }
}

pub fn run() -> Result<(), String> {
    StatusDaemon::new().run()
}

pub fn parse_wpctl_volume(stdout: &str, ok: bool, stderr: &str) -> AudioStatus {
    let muted = stdout.contains("[MUTED]");
    let mut level = 0;
    for token in stdout.split_whitespace() {
        if let Ok(value) = token.parse::<f64>() {
            level = (value * 100.0).round() as i32;
            break;
        }
    }
    let level = level.clamp(0, 150);
    AudioStatus {
        ok,
        level,
        muted,
        degraded: (!ok).then_some(true),
        error: (!ok).then(|| {
            let error = stderr.trim();
            if error.is_empty() {
                "wpctl_failed".to_string()
            } else {
                error.to_string()
            }
        }),
    }
}

pub fn format_rate(bytes_per_second: f64) -> String {
    let mut value = bytes_per_second.max(0.0);
    let units = ["B/s", "KB/s", "MB/s", "GB/s"];
    let mut index = 0;
    while value >= 1000.0 && index < units.len() - 1 {
        value /= 1000.0;
        index += 1;
    }
    if index == 0 {
        format!("{} {}", value.round() as i64, units[index])
    } else {
        format!("{value:.1} {}", units[index])
    }
}

pub fn default_route_iface_from_proc(text: &str) -> Option<String> {
    let mut best_iface = None;
    let mut best_metric = None;
    for line in text.lines().skip(1) {
        let mut fields = line.split_whitespace();
        let Some(iface) = fields.next() else {
            continue;
        };
        let Some(destination) = fields.next() else {
            continue;
        };
        if destination != "00000000" {
            continue;
        }
        let _gateway = fields.next();
        let Some(flags) = fields.next() else {
            continue;
        };
        let _refcnt = fields.next();
        let _use = fields.next();
        let Some(metric) = fields.next() else {
            continue;
        };
        let Ok(flags) = u32::from_str_radix(flags, 16) else {
            continue;
        };
        let Ok(metric) = metric.parse::<u32>() else {
            continue;
        };
        if flags & 0x2 == 0 {
            continue;
        }
        if best_metric.is_none_or(|current| metric < current) {
            best_iface = Some(iface.to_string());
            best_metric = Some(metric);
        }
    }
    best_iface
}

fn parse_route_get_iface(stdout: &str) -> Option<String> {
    let mut previous_was_dev = false;
    for token in stdout.split_whitespace() {
        if previous_was_dev {
            return Some(token.to_string());
        }
        previous_was_dev = token == "dev";
    }
    None
}

fn interface_counters(iface: &str) -> Option<(u64, u64)> {
    let stats = Path::new("/sys/class/net").join(iface).join("statistics");
    let rx = fs::read_to_string(stats.join("rx_bytes"))
        .ok()?
        .trim()
        .parse::<u64>()
        .ok()?;
    let tx = fs::read_to_string(stats.join("tx_bytes"))
        .ok()?
        .trim()
        .parse::<u64>()
        .ok()?;
    Some((rx, tx))
}

fn dependency_payload(name: &str, kind: &str, mut extra: Value) -> Value {
    let object = extra
        .as_object_mut()
        .expect("dependency payload must be object");
    object.insert("ok".to_string(), Value::Bool(false));
    object.insert("degraded".to_string(), Value::Bool(true));
    object.insert("error".to_string(), Value::String(kind.to_string()));
    object.insert(
        "message".to_string(),
        Value::String(format!("Missing dependency: {name}")),
    );
    extra
}

fn bluetooth_defaults() -> Value {
    json!({
        "powered": false,
        "connected_name": "",
        "paired_devices": [],
    })
}

fn ensure_bluetooth_defaults(payload: &mut Value) {
    if !payload.is_object() {
        *payload = json!({});
    }
    let object = payload.as_object_mut().expect("payload is object");
    object.entry("powered").or_insert(Value::Bool(false));
    object
        .entry("connected_name")
        .or_insert(Value::String(String::new()));
    object
        .entry("paired_devices")
        .or_insert_with(|| Value::Array(Vec::new()));
}

fn command_exists(command: &str) -> bool {
    if command.contains('/') {
        return Path::new(command).is_file();
    }
    env::var_os("PATH").is_some_and(|path| {
        env::split_paths(&path).any(|dir| {
            let candidate = dir.join(command);
            candidate.is_file()
        })
    })
}

fn run_command(args: &[&str], timeout: Duration) -> CommandResult {
    let mut child = match Command::new(args[0])
        .args(&args[1..])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(err) => {
            return CommandResult {
                ok: false,
                stdout: String::new(),
                stderr: err.to_string(),
            };
        }
    };
    let deadline = Instant::now() + timeout;
    loop {
        match child.try_wait() {
            Ok(Some(_)) => break,
            Ok(None) if Instant::now() < deadline => thread::sleep(Duration::from_millis(20)),
            Ok(None) => {
                let _ = child.kill();
                let _ = child.wait();
                return CommandResult {
                    ok: false,
                    stdout: String::new(),
                    stderr: "command timed out".to_string(),
                };
            }
            Err(err) => {
                return CommandResult {
                    ok: false,
                    stdout: String::new(),
                    stderr: err.to_string(),
                };
            }
        }
    }
    output_to_result(child.wait_with_output())
}

fn output_to_result(output: std::io::Result<Output>) -> CommandResult {
    match output {
        Ok(output) => CommandResult {
            ok: output.status.success(),
            stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
            stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
        },
        Err(err) => CommandResult {
            ok: false,
            stdout: String::new(),
            stderr: err.to_string(),
        },
    }
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_route_iface_prefers_lowest_metric_proc_route() {
        let route = "Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT\n\
wlan0\t00000000\t0164A8C0\t0003\t0\t0\t600\t00000000\t0\t0\t0\n\
eno1\t00000000\t0164A8C0\t0003\t0\t0\t100\t00000000\t0\t0\t0\n\
lo\t0000007F\t00000000\t0001\t0\t0\t0\t000000FF\t0\t0\t0\n";

        assert_eq!(
            default_route_iface_from_proc(route),
            Some("eno1".to_string())
        );
    }

    #[test]
    fn format_rate_matches_existing_status_payload_shape() {
        assert_eq!(format_rate(0.0), "0 B/s");
        assert_eq!(format_rate(1500.0), "1.5 KB/s");
        assert_eq!(format_rate(2_500_000.0), "2.5 MB/s");
    }

    #[test]
    fn audio_status_parser_reads_level_and_mute_flag() {
        let audio = parse_wpctl_volume("Volume: 0.37 [MUTED]\n", true, "");

        assert_eq!(audio.level, 37);
        assert!(audio.muted);
        assert!(audio.ok);
    }

    #[test]
    fn parse_route_get_iface_reads_dev_token() {
        assert_eq!(
            parse_route_get_iface("1.1.1.1 via 192.168.0.1 dev eno1 src 192.168.0.10"),
            Some("eno1".to_string())
        );
    }
}
