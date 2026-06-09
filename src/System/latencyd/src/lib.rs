use serde::Serialize;
use serde_json::{Map, Value, json};
use signal_hook::consts::signal::{SIGINT, SIGTERM};
use signal_hook::iterator::Signals;
use std::env;
use std::fs::{self, OpenOptions};
use std::io::{self, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::io::AsRawFd;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

pub const DEFAULT_DURATION_MS: u64 = 3000;
pub const MAX_BURST_MS: u64 = 3000;
const MIN_DURATION_MS: u64 = 250;
const DEFAULT_HISTORY_LIMIT: usize = 400;
const APP_NAME: &str = "Astrea";
const INTEL_NO_TURBO: &str = "/sys/devices/system/cpu/intel_pstate/no_turbo";
const BURST_HELPER: &str = "/usr/local/libexec/astrea-latency-burst-helper";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum WaitEvent {
    Connection,
    Wake,
    Timeout,
}

#[derive(Debug, Clone)]
struct CommandResult {
    ok: bool,
    stdout: String,
    stderr: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct Boost {
    pub reason: String,
    pub deadline_ms: u64,
    pub pid: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct LatencyDaemon {
    pub active: bool,
    pub previous_profile: Option<String>,
    pub previous_governors: Map<String, Value>,
    pub previous_no_turbo: Option<String>,
    pub privileged_snapshot: Option<Value>,
    pub boosts: Vec<Boost>,
    pub details: Vec<String>,
    running: Arc<AtomicBool>,
}

impl Default for LatencyDaemon {
    fn default() -> Self {
        Self {
            active: false,
            previous_profile: None,
            previous_governors: Map::new(),
            previous_no_turbo: None,
            privileged_snapshot: None,
            boosts: Vec::new(),
            details: Vec::new(),
            running: Arc::new(AtomicBool::new(true)),
        }
    }
}

impl LatencyDaemon {
    pub fn rollback_payload(&self) -> Option<Value> {
        self.active.then(|| {
            json!({
                "previous_profile": self.previous_profile,
                "previous_governors": self.previous_governors,
                "previous_no_turbo": self.previous_no_turbo,
                "privileged_snapshot": self.privileged_snapshot,
            })
        })
    }

    fn handle_payload(&mut self, payload: Value) {
        if payload.get("op").and_then(Value::as_str) != Some("boost") {
            self.record("ignored", payload, vec!["unknown op".to_string()]);
            return;
        }

        let reason = payload
            .get("reason")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .unwrap_or("unspecified")
            .to_string();
        let duration_ms = parse_duration_ms(value_as_u64(payload.get("duration_ms")));
        let pid = parse_pid(payload.get("pid"));
        let deadline_ms = now_ms().saturating_add(duration_ms);

        if !self.active {
            self.previous_profile = read_power_profile();
            self.previous_governors = snapshot_cpu_governors();
            self.previous_no_turbo = read_text(Path::new(INTEL_NO_TURBO));
            self.active = true;
            let (privileged_snapshot, privileged_details) = privileged_burst();
            self.privileged_snapshot = privileged_snapshot;
            self.details.extend(privileged_details);
            if self.privileged_snapshot.is_none() {
                self.details.push(set_power_profile("performance"));
                self.details.extend(set_cpu_governor("performance"));
                self.details.push(set_intel_turbo(true));
            }
            self.details.extend(apply_gpu_burst());
        }

        let mut boost_details = vec![format!("boost {reason} for {duration_ms}ms")];
        if let Some(pid) = pid {
            boost_details.extend(boost_pid(pid));
        }
        self.boosts.push(Boost {
            reason,
            deadline_ms,
            pid,
        });
        self.prune_expired();
        self.record("boost", payload, boost_details);
        if let Err(error) = self.write_state() {
            self.record(
                "error",
                json!({"op": "write-state"}),
                vec![format!("write state failed: {error}")],
            );
        }
    }

    fn prune_expired(&mut self) {
        let current = now_ms();
        self.boosts.retain(|boost| boost.deadline_ms > current);
        if self.active && self.boosts.is_empty() {
            self.rollback("rollback", json!({"op": "rollback"}), Vec::<String>::new());
        }
    }

    fn rollback(
        &mut self,
        event: &str,
        payload: Value,
        leading_details: Vec<String>,
    ) -> Vec<String> {
        if !self.active {
            return Vec::new();
        }

        let mut details = leading_details;
        if self
            .previous_profile
            .as_deref()
            .is_some_and(|profile| profile != "performance")
        {
            if let Some(profile) = &self.previous_profile {
                details.push(set_power_profile(profile));
            }
        }
        details.extend(privileged_restore(&self.privileged_snapshot));
        if self.privileged_snapshot.is_none() {
            details.extend(restore_cpu_governors(&self.previous_governors));
            if let Some(value) = &self.previous_no_turbo {
                let (ok, detail) =
                    write_text(Path::new(INTEL_NO_TURBO), &(value.to_string() + "\n"));
                details.push(if ok {
                    "intel turbo restored".to_string()
                } else {
                    format!("{detail}; {}", privilege_unavailable("intel turbo restore"))
                });
            }
        }

        self.active = false;
        self.previous_profile = None;
        self.previous_governors = Map::new();
        self.previous_no_turbo = None;
        self.privileged_snapshot = None;
        self.boosts.clear();
        self.details = details.clone();
        self.record(
            event,
            payload,
            if details.is_empty() {
                vec!["nothing to rollback".to_string()]
            } else {
                details.clone()
            },
        );
        let _ = self.write_state();
        details
    }

    fn next_timeout(&mut self) -> Duration {
        self.prune_expired();
        let Some(deadline) = self.boosts.iter().map(|boost| boost.deadline_ms).min() else {
            return Duration::from_secs(5);
        };
        let remaining_ms = deadline.saturating_sub(now_ms());
        Duration::from_millis(remaining_ms.clamp(50, 5000))
    }

    fn write_state(&self) -> Result<(), String> {
        let details_start = self.details.len().saturating_sub(12);
        let payload = json!({
            "active": self.active,
            "now_ms": now_ms(),
            "previous_profile": self.previous_profile,
            "current_profile": read_power_profile(),
            "cpu_governors": snapshot_cpu_governors(),
            "boosts": self.boosts,
            "rollback": self.rollback_payload(),
            "details": self.details[details_start..],
            "socket": socket_path().to_string_lossy(),
        });
        atomic_write_json(&state_path(), &payload)
    }

    fn record(&self, event: &str, payload: Value, details: Vec<String>) {
        let _ = append_history(&json!({
            "timestamp_ms": now_ms(),
            "event": event,
            "payload": payload,
            "details": details,
        }));
    }
}

pub fn parse_duration_ms(value: Option<u64>) -> u64 {
    value
        .unwrap_or(DEFAULT_DURATION_MS)
        .clamp(MIN_DURATION_MS, MAX_BURST_MS)
}

pub fn read_request_lines(conn: &mut UnixStream, max_bytes: usize) -> io::Result<Vec<Vec<u8>>> {
    let previous_timeout = conn.read_timeout().ok().flatten();
    let _ = conn.set_read_timeout(Some(Duration::from_millis(500)));
    let result = read_request_lines_inner(conn, max_bytes);
    let _ = conn.set_read_timeout(previous_timeout);
    result
}

fn read_request_lines_inner(conn: &mut UnixStream, max_bytes: usize) -> io::Result<Vec<Vec<u8>>> {
    let mut data = Vec::new();
    let mut buffer = [0_u8; 8192];
    loop {
        match conn.read(&mut buffer) {
            Ok(0) => break,
            Ok(read) => {
                data.extend_from_slice(&buffer[..read]);
                if data.len() > max_bytes {
                    return Err(io::Error::new(
                        io::ErrorKind::InvalidData,
                        format!("request too large: {} bytes", data.len()),
                    ));
                }
            }
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                break;
            }
            Err(error) => return Err(error),
        }
    }

    Ok(data
        .split(|byte| *byte == b'\n')
        .filter(|line| line.iter().any(|byte| !byte.is_ascii_whitespace()))
        .map(|line| line.trim_ascii().to_vec())
        .collect())
}

pub fn run_cli() -> Result<(), String> {
    let command = env::args().nth(1).unwrap_or_else(|| "serve".to_string());
    match command.as_str() {
        "serve" => serve(),
        "doctor" => doctor(),
        "status" => status(),
        "self-test" => self_test(),
        _ => Err(format!(
            "usage: {} [serve|doctor|status|self-test]",
            env::args()
                .next()
                .unwrap_or_else(|| "astrea-latencyd".to_string())
        )),
    }
}

fn handle_connection(daemon: &mut LatencyDaemon, conn: &mut UnixStream) {
    let lines = match read_request_lines(conn, max_request_bytes()) {
        Ok(lines) => lines,
        Err(error) => {
            daemon.record("error", json!({"raw": ""}), vec![error.to_string()]);
            return;
        }
    };

    for line in lines {
        let raw = String::from_utf8_lossy(&line).into_owned();
        match serde_json::from_slice::<Value>(&line) {
            Ok(payload) => daemon.handle_payload(payload),
            Err(error) => daemon.record("error", json!({"raw": raw}), vec![error.to_string()]),
        }
    }
}

fn serve() -> Result<(), String> {
    let path = socket_path();
    fs::create_dir_all(
        path.parent()
            .ok_or_else(|| format!("missing socket parent: {}", path.display()))?,
    )
    .map_err(|error| format!("create socket dir: {error}"))?;
    match fs::remove_file(&path) {
        Ok(()) => {}
        Err(error) if error.kind() == io::ErrorKind::NotFound => {}
        Err(error) => return Err(format!("remove stale socket: {error}")),
    }

    let mut daemon = LatencyDaemon::default();
    let _ = recover_pending_rollback();
    trim_history(&history_path(), history_limit());
    let (wake_writer, mut wake_reader) =
        UnixStream::pair().map_err(|error| format!("create wake pipe: {error}"))?;
    wake_reader
        .set_nonblocking(true)
        .map_err(|error| format!("set wake pipe nonblocking: {error}"))?;
    install_signal_handlers(&daemon, wake_writer)?;

    let listener = UnixListener::bind(&path).map_err(|error| format!("bind socket: {error}"))?;
    fs::set_permissions(&path, fs::Permissions::from_mode(0o600))
        .map_err(|error| format!("chmod socket: {error}"))?;
    listener
        .set_nonblocking(true)
        .map_err(|error| format!("set nonblocking: {error}"))?;
    daemon.write_state()?;

    while daemon.running.load(Ordering::Relaxed) {
        daemon.prune_expired();
        match wait_for_event(&listener, &mut wake_reader, daemon.next_timeout()) {
            Ok(WaitEvent::Connection) => loop {
                match listener.accept() {
                    Ok((mut conn, _addr)) => handle_connection(&mut daemon, &mut conn),
                    Err(error) if error.kind() == io::ErrorKind::WouldBlock => break,
                    Err(error) => {
                        daemon.record(
                            "error",
                            json!({"op": "accept"}),
                            vec![format!("accept failed: {error}")],
                        );
                        break;
                    }
                }
            },
            Ok(WaitEvent::Timeout) => daemon.prune_expired(),
            Ok(WaitEvent::Wake) => break,
            Err(error) => daemon.record(
                "error",
                json!({"op": "poll"}),
                vec![format!("poll failed: {error}")],
            ),
        }
    }

    if daemon.active {
        daemon.rollback("rollback", json!({"op": "rollback"}), Vec::<String>::new());
    }
    let _ = fs::remove_file(path);
    Ok(())
}

fn wait_for_event(
    listener: &UnixListener,
    wake_reader: &mut UnixStream,
    timeout: Duration,
) -> io::Result<WaitEvent> {
    let mut fds = [
        libc::pollfd {
            fd: listener.as_raw_fd(),
            events: libc::POLLIN,
            revents: 0,
        },
        libc::pollfd {
            fd: wake_reader.as_raw_fd(),
            events: libc::POLLIN,
            revents: 0,
        },
    ];

    loop {
        let result = unsafe {
            libc::poll(
                fds.as_mut_ptr(),
                fds.len() as libc::nfds_t,
                poll_timeout_ms(timeout),
            )
        };
        if result < 0 {
            let error = io::Error::last_os_error();
            if error.kind() == io::ErrorKind::Interrupted {
                continue;
            }
            return Err(error);
        }
        if result == 0 {
            return Ok(WaitEvent::Timeout);
        }

        let wake_events = fds[1].revents;
        if wake_events & (libc::POLLIN | libc::POLLHUP | libc::POLLERR) != 0 {
            drain_wake_pipe(wake_reader);
            return Ok(WaitEvent::Wake);
        }

        let listener_events = fds[0].revents;
        if listener_events & (libc::POLLIN | libc::POLLHUP | libc::POLLERR) != 0 {
            return Ok(WaitEvent::Connection);
        }
    }
}

fn poll_timeout_ms(timeout: Duration) -> i32 {
    timeout.as_millis().min(5000).min(i32::MAX as u128) as i32
}

fn drain_wake_pipe(wake_reader: &mut UnixStream) {
    let mut buffer = [0_u8; 64];
    loop {
        match wake_reader.read(&mut buffer) {
            Ok(0) => break,
            Ok(_) => {}
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                break;
            }
            Err(_) => break,
        }
    }
}

fn doctor() -> Result<(), String> {
    let payload = json!({
        "socket": socket_path().to_string_lossy(),
        "socket_exists": socket_path().exists(),
        "state": state_path().to_string_lossy(),
        "history": history_path().to_string_lossy(),
        "powerprofilesctl": command_available("powerprofilesctl"),
        "current_profile": read_power_profile(),
        "cpu_governors": snapshot_cpu_governors(),
        "intel_no_turbo": read_text(Path::new(INTEL_NO_TURBO)),
        "renice": command_available("renice"),
        "ionice": command_available("ionice"),
    });
    println!(
        "{}",
        serde_json::to_string_pretty(&payload).map_err(|error| error.to_string())?
    );
    Ok(())
}

fn status() -> Result<(), String> {
    match fs::read_to_string(state_path()) {
        Ok(text) => {
            print!("{text}");
            Ok(())
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => {
            println!("{{}}");
            Ok(())
        }
        Err(error) => Err(format!("read state: {error}")),
    }
}

fn self_test() -> Result<(), String> {
    let path = socket_path();
    if !path.exists() {
        return Err(format!("socket missing: {}", path.display()));
    }
    let payload = json!({
        "op": "boost",
        "reason": "self-test",
        "duration_ms": 750,
        "source": "astrea-latencyd",
    });
    let mut client =
        UnixStream::connect(&path).map_err(|error| format!("connect socket: {error}"))?;
    let line = serde_json::to_string(&payload).map_err(|error| error.to_string())? + "\n";
    client
        .write_all(line.as_bytes())
        .map_err(|error| format!("write request: {error}"))
}

fn install_signal_handlers(
    daemon: &LatencyDaemon,
    mut wake_writer: UnixStream,
) -> Result<(), String> {
    let mut signals =
        Signals::new([SIGTERM, SIGINT]).map_err(|error| format!("register signals: {error}"))?;
    let running = Arc::clone(&daemon.running);
    thread::spawn(move || {
        for _signal in signals.forever() {
            running.store(false, Ordering::Relaxed);
            let _ = wake_writer.write_all(&[1]);
            break;
        }
    });
    Ok(())
}

fn recover_pending_rollback() -> Vec<String> {
    let payload = match fs::read_to_string(state_path())
        .ok()
        .and_then(|text| serde_json::from_str::<Value>(&text).ok())
    {
        Some(payload) => payload,
        None => return Vec::new(),
    };
    if !payload
        .get("active")
        .and_then(Value::as_bool)
        .unwrap_or(false)
    {
        return Vec::new();
    }
    let Some(rollback) = payload.get("rollback").and_then(Value::as_object) else {
        return Vec::new();
    };

    let previous_governors = rollback
        .get("previous_governors")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    let previous_no_turbo = rollback
        .get("previous_no_turbo")
        .and_then(Value::as_str)
        .filter(|value| *value == "0" || *value == "1")
        .map(ToOwned::to_owned);
    let privileged_snapshot = rollback
        .get("privileged_snapshot")
        .filter(|value| value.is_object())
        .cloned();

    let mut daemon = LatencyDaemon {
        active: true,
        previous_profile: rollback
            .get("previous_profile")
            .and_then(Value::as_str)
            .map(ToOwned::to_owned),
        previous_governors,
        previous_no_turbo,
        privileged_snapshot,
        ..LatencyDaemon::default()
    };
    daemon.rollback(
        "recover-rollback",
        json!({"op": "recover-rollback"}),
        vec!["recovered stale boost rollback".to_string()],
    )
}

fn value_as_u64(value: Option<&Value>) -> Option<u64> {
    value.and_then(|value| {
        value
            .as_u64()
            .or_else(|| value.as_i64().map(|number| number.max(0) as u64))
            .or_else(|| value.as_str().and_then(|text| text.parse::<u64>().ok()))
    })
}

fn parse_pid(value: Option<&Value>) -> Option<i64> {
    let pid = value.and_then(|value| {
        value
            .as_i64()
            .or_else(|| value.as_u64().and_then(|number| i64::try_from(number).ok()))
            .or_else(|| value.as_str().and_then(|text| text.parse::<i64>().ok()))
    })?;
    (pid > 0).then_some(pid)
}

fn xdg_state_home() -> PathBuf {
    env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/state"))
}

fn xdg_runtime_dir() -> PathBuf {
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| xdg_state_home().join(APP_NAME).join("runtime"))
}

fn socket_path() -> PathBuf {
    xdg_runtime_dir()
        .join(APP_NAME)
        .join("astrea-latencyd.sock")
}

fn state_dir() -> PathBuf {
    xdg_state_home().join(APP_NAME).join("latencyd")
}

fn state_path() -> PathBuf {
    state_dir().join("state.json")
}

fn history_path() -> PathBuf {
    state_dir().join("history.jsonl")
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn max_request_bytes() -> usize {
    env::var("ASTREA_LATENCYD_MAX_REQUEST_BYTES")
        .ok()
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(65_536)
}

fn history_limit() -> usize {
    env::var("ASTREA_LATENCYD_HISTORY_LIMIT")
        .ok()
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(DEFAULT_HISTORY_LIMIT)
}

fn command_available(name: &str) -> bool {
    if name.contains('/') {
        return Path::new(name).is_file();
    }
    env::var_os("PATH").is_some_and(|path| {
        env::split_paths(&path).any(|dir| {
            let candidate = dir.join(name);
            candidate.is_file()
        })
    })
}

fn run_command(args: &[String], timeout: Duration) -> CommandResult {
    if args.is_empty() {
        return CommandResult {
            ok: false,
            stdout: String::new(),
            stderr: "missing command".to_string(),
        };
    }
    let mut child = match Command::new(&args[0])
        .args(&args[1..])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(error) => {
            return CommandResult {
                ok: false,
                stdout: String::new(),
                stderr: error.to_string(),
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
                    stderr: "timeout".to_string(),
                };
            }
            Err(error) => {
                return CommandResult {
                    ok: false,
                    stdout: String::new(),
                    stderr: error.to_string(),
                };
            }
        }
    }
    output_to_result(child.wait_with_output())
}

fn output_to_result(output: io::Result<Output>) -> CommandResult {
    match output {
        Ok(output) => CommandResult {
            ok: output.status.success(),
            stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
            stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
        },
        Err(error) => CommandResult {
            ok: false,
            stdout: String::new(),
            stderr: error.to_string(),
        },
    }
}

fn read_power_profile() -> Option<String> {
    if !command_available("powerprofilesctl") {
        return None;
    }
    let output = run_command(
        &["powerprofilesctl".to_string(), "get".to_string()],
        Duration::from_millis(1500),
    );
    output
        .ok
        .then(|| output.stdout.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn set_power_profile(profile: &str) -> String {
    if !command_available("powerprofilesctl") {
        return "powerprofilesctl missing".to_string();
    }
    let output = run_command(
        &[
            "powerprofilesctl".to_string(),
            "set".to_string(),
            profile.to_string(),
        ],
        Duration::from_millis(1500),
    );
    if output.ok {
        format!("power profile -> {profile}")
    } else {
        output_error(&output, "power profile failed")
    }
}

fn read_text(path: &Path) -> Option<String> {
    fs::read_to_string(path)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn write_text(path: &Path, value: &str) -> (bool, String) {
    match fs::write(path, value) {
        Ok(()) => (true, format!("{} -> {}", path.display(), value.trim())),
        Err(error) => (false, format!("{}: {error}", path.display())),
    }
}

fn privilege_unavailable(action: &str) -> String {
    format!("privileged helper required for {action}")
}

fn cpu_governor_paths() -> Vec<PathBuf> {
    let mut paths = fs::read_dir("/sys/devices/system/cpu/cpufreq")
        .ok()
        .into_iter()
        .flat_map(|entries| entries.filter_map(Result::ok))
        .filter_map(|entry| {
            let name = entry.file_name();
            let name = name.to_string_lossy();
            name.starts_with("policy")
                .then(|| entry.path().join("scaling_governor"))
                .filter(|path| path.exists())
        })
        .collect::<Vec<_>>();
    paths.sort();
    paths
}

fn snapshot_cpu_governors() -> Map<String, Value> {
    let mut snapshot = Map::new();
    for path in cpu_governor_paths() {
        if let Some(value) = read_text(&path) {
            snapshot.insert(path.to_string_lossy().to_string(), Value::String(value));
        }
    }
    snapshot
}

fn set_cpu_governor(governor: &str) -> Vec<String> {
    let mut details = Vec::new();
    let paths = cpu_governor_paths();
    let mut changed_direct = 0;
    for path in &paths {
        let (ok, detail) = write_text(path, &(governor.to_string() + "\n"));
        if ok {
            changed_direct += 1;
        } else if details.len() < 4 {
            details.push(detail);
        }
    }

    if changed_direct == paths.len() && !paths.is_empty() {
        return vec![format!(
            "cpu governors -> {governor} direct ({changed_direct})"
        )];
    }
    if changed_direct > 0 {
        details.push(format!(
            "cpu governors -> {governor} direct partial ({changed_direct}/{})",
            paths.len()
        ));
    }

    if command_available("cpupower") {
        let output = run_command(
            &[
                "cpupower".to_string(),
                "frequency-set".to_string(),
                "-g".to_string(),
                governor.to_string(),
            ],
            Duration::from_millis(1500),
        );
        if output.ok {
            details.push(format!("cpupower governor -> {governor}"));
            return details;
        }
        details.push(format!("cpupower: {}", output_error(&output, "failed")));
    }

    details.push(privilege_unavailable("cpu governor"));
    details
}

fn restore_cpu_governors(snapshot: &Map<String, Value>) -> Vec<String> {
    if snapshot.is_empty() {
        return vec!["no cpu governor snapshot".to_string()];
    }
    let mut details = Vec::new();
    let mut failed = Map::new();
    for (path, governor) in snapshot {
        let Some(governor) = governor.as_str() else {
            continue;
        };
        let (ok, detail) = write_text(Path::new(path), &(governor.to_string() + "\n"));
        if !ok {
            failed.insert(path.clone(), Value::String(governor.to_string()));
            if details.len() < 4 {
                details.push(detail);
            }
        }
    }
    if failed.is_empty() {
        return vec![format!(
            "cpu governors restored direct ({})",
            snapshot.len()
        )];
    }
    let mut unique_governors = failed
        .values()
        .filter_map(Value::as_str)
        .map(ToOwned::to_owned)
        .collect::<Vec<_>>();
    unique_governors.sort();
    unique_governors.dedup();
    if unique_governors.len() == 1 && command_available("cpupower") {
        let governor = &unique_governors[0];
        let output = run_command(
            &[
                "cpupower".to_string(),
                "frequency-set".to_string(),
                "-g".to_string(),
                governor.to_string(),
            ],
            Duration::from_millis(1500),
        );
        if output.ok {
            details.push(format!("cpupower governor restored -> {governor}"));
            return details;
        }
        details.push(format!(
            "cpupower restore: {}",
            output_error(&output, "failed")
        ));
    }
    details.push(privilege_unavailable("cpu governor restore"));
    details
}

fn set_intel_turbo(enabled: bool) -> String {
    let path = Path::new(INTEL_NO_TURBO);
    if !path.exists() {
        return "intel turbo knob missing".to_string();
    }
    let value = if enabled { "0\n" } else { "1\n" };
    let (ok, detail) = write_text(path, value);
    if ok {
        if enabled {
            "intel turbo enabled".to_string()
        } else {
            "intel turbo disabled".to_string()
        }
    } else {
        format!("{detail}; {}", privilege_unavailable("intel turbo"))
    }
}

fn run_burst_helper(args: &[String], timeout: Duration) -> Option<Value> {
    if !Path::new(BURST_HELPER).exists() || !command_available("sudo") {
        return None;
    }
    let mut command = vec![
        "sudo".to_string(),
        "-n".to_string(),
        BURST_HELPER.to_string(),
    ];
    command.extend(args.iter().cloned());
    let output = run_command(&command, timeout);
    let text = output.stdout.trim();
    if !output.ok {
        return Some(json!({
            "ok": false,
            "details": [output_error(&output, "helper failed")]
        }));
    }
    match serde_json::from_str::<Value>(if text.is_empty() { "{}" } else { text }) {
        Ok(payload) => Some(payload),
        Err(_) => Some(json!({
            "ok": false,
            "details": [format!("helper returned invalid json: {text}")]
        })),
    }
}

fn value_details(payload: &Value) -> Vec<String> {
    payload
        .get("details")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .map(|item| {
                    item.as_str()
                        .map(ToOwned::to_owned)
                        .unwrap_or_else(|| item.to_string())
                })
                .collect()
        })
        .unwrap_or_default()
}

fn privileged_burst() -> (Option<Value>, Vec<String>) {
    let payload = match run_burst_helper(&["burst".to_string()], Duration::from_millis(1500)) {
        Some(payload) => payload,
        None => return (None, vec!["burst helper unavailable".to_string()]),
    };
    let details = value_details(&payload);
    if payload.get("ok").and_then(Value::as_bool).unwrap_or(false) {
        let snapshot = payload
            .get("snapshot")
            .filter(|snapshot| snapshot.is_object())
            .cloned();
        return (
            snapshot,
            ["burst helper ok".to_string()]
                .into_iter()
                .chain(details)
                .collect(),
        );
    }
    (
        None,
        ["burst helper failed".to_string()]
            .into_iter()
            .chain(details)
            .collect(),
    )
}

fn privileged_restore(snapshot: &Option<Value>) -> Vec<String> {
    let Some(snapshot) = snapshot else {
        return vec!["no privileged burst snapshot".to_string()];
    };
    let snapshot_text = serde_json::to_string(snapshot).unwrap_or_else(|_| "{}".to_string());
    let payload = match run_burst_helper(
        &["restore".to_string(), snapshot_text],
        Duration::from_millis(1500),
    ) {
        Some(payload) => payload,
        None => return vec!["burst helper unavailable for restore".to_string()],
    };
    let details = value_details(&payload);
    [
        if payload.get("ok").and_then(Value::as_bool).unwrap_or(false) {
            "burst helper restore ok".to_string()
        } else {
            "burst helper restore failed".to_string()
        },
    ]
    .into_iter()
    .chain(details)
    .collect()
}

fn privileged_pid_boost(pid: i64) -> Vec<String> {
    let payload = match run_burst_helper(
        &["pid".to_string(), pid.to_string()],
        Duration::from_millis(1500),
    ) {
        Some(payload) => payload,
        None => return vec!["burst helper unavailable for pid".to_string()],
    };
    let details = value_details(&payload);
    [
        if payload.get("ok").and_then(Value::as_bool).unwrap_or(false) {
            "burst helper pid ok".to_string()
        } else {
            "burst helper pid failed".to_string()
        },
    ]
    .into_iter()
    .chain(details)
    .collect()
}

fn apply_gpu_burst() -> Vec<String> {
    vec!["gpu burst skipped: rollback snapshot unsupported".to_string()]
}

fn boost_pid(pid: i64) -> Vec<String> {
    let mut details = Vec::new();
    if pid <= 0 || !Path::new(&format!("/proc/{pid}")).exists() {
        return vec![format!("pid {pid} not found")];
    }

    if command_available("gamemoded") {
        let output = run_command(
            &["gamemoded".to_string(), format!("-r{pid}")],
            Duration::from_millis(1500),
        );
        details.push(if output.ok {
            "gamemode pid toggle ok".to_string()
        } else {
            format!("gamemode: {}", output_error(&output, "failed"))
        });
    }

    let helper_details = privileged_pid_boost(pid);
    if !helper_details
        .first()
        .is_some_and(|detail| detail.ends_with("ok"))
    {
        if command_available("renice") {
            let output = run_command(
                &[
                    "renice".to_string(),
                    "-n".to_string(),
                    "-15".to_string(),
                    "-p".to_string(),
                    pid.to_string(),
                ],
                Duration::from_millis(1500),
            );
            details.push(if output.ok {
                "renice ok".to_string()
            } else {
                format!("renice: {}", output_error(&output, "failed"))
            });
        }
        if command_available("ionice") {
            let output = run_command(
                &[
                    "ionice".to_string(),
                    "-c".to_string(),
                    "2".to_string(),
                    "-n".to_string(),
                    "0".to_string(),
                    "-p".to_string(),
                    pid.to_string(),
                ],
                Duration::from_millis(1500),
            );
            details.push(if output.ok {
                "ionice ok".to_string()
            } else {
                format!("ionice: {}", output_error(&output, "failed"))
            });
        }
    }
    details.extend(helper_details);
    if details.is_empty() {
        vec!["no pid boost helpers available".to_string()]
    } else {
        details
    }
}

fn output_error(output: &CommandResult, fallback: &str) -> String {
    let stderr = output.stderr.trim();
    if !stderr.is_empty() {
        return stderr.to_string();
    }
    let stdout = output.stdout.trim();
    if !stdout.is_empty() {
        stdout.to_string()
    } else {
        fallback.to_string()
    }
}

fn atomic_write_json(path: &Path, payload: &Value) -> Result<(), String> {
    fs::create_dir_all(
        path.parent()
            .ok_or_else(|| format!("missing parent for {}", path.display()))?,
    )
    .map_err(|error| format!("create state dir: {error}"))?;
    let tmp = path.with_file_name(format!(
        ".{}.{}.tmp",
        path.file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("state"),
        std::process::id()
    ));
    let text = serde_json::to_string_pretty(payload).map_err(|error| error.to_string())? + "\n";
    fs::write(&tmp, text).map_err(|error| format!("write temp state: {error}"))?;
    fs::rename(&tmp, path).map_err(|error| format!("replace state: {error}"))
}

fn append_history(payload: &Value) -> Result<(), String> {
    let path = history_path();
    fs::create_dir_all(
        path.parent()
            .ok_or_else(|| format!("missing parent for {}", path.display()))?,
    )
    .map_err(|error| format!("create history dir: {error}"))?;
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|error| format!("open history: {error}"))?;
    let text = serde_json::to_string(payload).map_err(|error| error.to_string())? + "\n";
    file.write_all(text.as_bytes())
        .map_err(|error| format!("write history: {error}"))?;
    drop(file);
    trim_history(&path, history_limit());
    Ok(())
}

fn trim_history(path: &Path, limit: usize) {
    if limit == 0 {
        return;
    }
    let Ok(text) = fs::read_to_string(path) else {
        return;
    };
    let line_count = text.lines().count();
    if line_count <= limit {
        return;
    }
    let start = line_count - limit;
    let keep = text.lines().skip(start).collect::<Vec<_>>().join("\n") + "\n";
    let _ = fs::write(path, keep);
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis().min(u128::from(u64::MAX)) as u64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::io::Write;
    use std::net::Shutdown;
    use std::os::unix::net::UnixStream;

    #[test]
    fn read_request_lines_reassembles_large_json_line() {
        let payload = json!({"op": "boost", "reason": "x".repeat(9000)});
        let raw = serde_json::to_vec(&payload).unwrap();
        let (mut writer, mut reader) = UnixStream::pair().unwrap();
        writer.write_all(&raw[..4096]).unwrap();
        writer.write_all(&raw[4096..8192]).unwrap();
        writer.write_all(&raw[8192..]).unwrap();
        writer.write_all(b"\n").unwrap();
        writer.shutdown(Shutdown::Write).unwrap();

        let lines = read_request_lines(&mut reader, 65_536).unwrap();

        assert_eq!(lines, vec![raw]);
    }

    #[test]
    fn parse_duration_ms_clamps_short_and_long_requests() {
        assert_eq!(parse_duration_ms(Some(1)), 250);
        assert_eq!(parse_duration_ms(Some(10_000)), MAX_BURST_MS);
        assert_eq!(parse_duration_ms(None), DEFAULT_DURATION_MS);
    }

    #[test]
    fn rollback_payload_includes_previous_state_snapshot() {
        let mut previous_governors = serde_json::Map::new();
        previous_governors.insert(
            "/sys/policy0".to_string(),
            Value::String("schedutil".to_string()),
        );
        let daemon = LatencyDaemon {
            active: true,
            previous_profile: Some("balanced".to_string()),
            previous_governors,
            previous_no_turbo: Some("1".to_string()),
            privileged_snapshot: Some(json!({"intel_no_turbo": "1"})),
            ..LatencyDaemon::default()
        };

        let payload = daemon.rollback_payload().unwrap();

        assert_eq!(payload["previous_profile"], "balanced");
        assert_eq!(payload["previous_governors"]["/sys/policy0"], "schedutil");
        assert_eq!(payload["previous_no_turbo"], "1");
        assert_eq!(payload["privileged_snapshot"]["intel_no_turbo"], "1");
    }

    #[test]
    fn poll_timeout_ms_clamps_duration_for_kernel_poll() {
        assert_eq!(poll_timeout_ms(Duration::from_millis(0)), 0);
        assert_eq!(poll_timeout_ms(Duration::from_millis(42)), 42);
        assert_eq!(poll_timeout_ms(Duration::from_secs(10)), 5000);
    }

    #[test]
    fn wait_for_event_wakes_from_signal_pipe() {
        let dir = tempfile_dir("latencyd-wake");
        let socket = dir.join("wake.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        listener.set_nonblocking(true).unwrap();
        let (mut wake_writer, mut wake_reader) = UnixStream::pair().unwrap();
        wake_reader.set_nonblocking(true).unwrap();
        wake_writer.write_all(&[1]).unwrap();

        let event = wait_for_event(&listener, &mut wake_reader, Duration::from_secs(5)).unwrap();

        assert_eq!(event, WaitEvent::Wake);
    }

    #[test]
    fn wait_for_event_wakes_when_socket_has_connection() {
        let dir = tempfile_dir("latencyd-connection");
        let socket = dir.join("connection.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        listener.set_nonblocking(true).unwrap();
        let (_wake_writer, mut wake_reader) = UnixStream::pair().unwrap();
        wake_reader.set_nonblocking(true).unwrap();
        let _client = UnixStream::connect(&socket).unwrap();

        let event = wait_for_event(&listener, &mut wake_reader, Duration::from_secs(5)).unwrap();

        assert_eq!(event, WaitEvent::Connection);
    }

    #[test]
    fn trim_history_keeps_only_newest_lines() {
        let dir = tempfile_dir("latencyd-history");
        let path = dir.join("history.jsonl");
        fs::write(&path, "one\ntwo\nthree\nfour\n").unwrap();

        trim_history(&path, 2);

        assert_eq!(fs::read_to_string(path).unwrap(), "three\nfour\n");
    }

    fn tempfile_dir(name: &str) -> PathBuf {
        let dir = env::temp_dir().join(format!("{name}-{}-{}", std::process::id(), now_ms()));
        fs::create_dir_all(&dir).unwrap();
        dir
    }
}
