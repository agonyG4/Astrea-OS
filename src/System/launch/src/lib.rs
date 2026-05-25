use serde::{Deserialize, Serialize};
use std::env;
use std::fs::{self, OpenOptions};
use std::io::{Read, Write};
use std::net::Shutdown;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{self, Command, Stdio};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const DEFAULT_BOOST_MS: u64 = 3000;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum LaunchRequest {
    Desktop {
        id: String,
    },
    Command {
        command: String,
    },
    Argv {
        argv: Vec<String>,
        working_dir: Option<String>,
    },
    File {
        path: String,
    },
    Url {
        url: String,
    },
    Steam {
        uri: String,
    },
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CommandSpec {
    pub argv: Vec<String>,
    pub working_dir: Option<PathBuf>,
    pub desktop_file: Option<PathBuf>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(default)]
pub struct LaunchConfig {
    pub default_external_boost_ms: u64,
    pub allow_nvidia_env: bool,
    pub isolate_launches: bool,
    pub history_limit: usize,
    pub latency: LatencyConfig,
    pub rules: Vec<Rule>,
}

impl Default for LaunchConfig {
    fn default() -> Self {
        Self {
            default_external_boost_ms: DEFAULT_BOOST_MS,
            allow_nvidia_env: false,
            isolate_launches: true,
            history_limit: 200,
            latency: LatencyConfig::default(),
            rules: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(default)]
pub struct LatencyConfig {
    pub enabled: bool,
    pub socket_paths: Vec<String>,
    pub command: Option<Vec<String>>,
}

impl Default for LatencyConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            socket_paths: default_latency_socket_paths(),
            command: None,
        }
    }
}

#[derive(Debug, Clone, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(default)]
pub struct Rule {
    pub desktop_id: Option<String>,
    pub executable: Option<String>,
    pub command_substring: Option<String>,
    pub steam_appid: Option<String>,
    pub env: Vec<(String, String)>,
    pub working_dir: Option<String>,
    pub launch_boost_ms: Option<u64>,
    pub allow_external_pid_boost: Option<bool>,
    pub game_mode_preset: Option<String>,
    pub steam_compat_preset: Option<String>,
    pub nvidia_env: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LaunchRecord {
    pub timestamp_ms: u128,
    pub kind: String,
    pub target: String,
    pub argv: Vec<String>,
    pub pid: Option<u32>,
    pub status: String,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct LaunchDaemonResponse {
    ok: bool,
    record: Option<LaunchRecord>,
    error: Option<String>,
}

#[derive(Debug)]
enum LaunchdError {
    Connect,
    Request(String),
}

pub fn config_path() -> PathBuf {
    xdg_config_home().join("AstreaOS/system/launch.json")
}

pub fn history_path() -> PathBuf {
    xdg_state_home().join("Astrea/launch/history.jsonl")
}

pub fn launchd_socket_path() -> PathBuf {
    xdg_runtime_dir()
        .unwrap_or_else(|| xdg_state_home().join("Astrea/runtime"))
        .join("Astrea/astrea-launchd.sock")
}

pub fn load_config() -> (LaunchConfig, Option<String>) {
    let path = config_path();
    match fs::read_to_string(&path) {
        Ok(text) => match serde_json::from_str::<LaunchConfig>(&text) {
            Ok(config) => (config, None),
            Err(err) => (
                LaunchConfig::default(),
                Some(format!("config parse failed: {err}")),
            ),
        },
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => (LaunchConfig::default(), None),
        Err(err) => (
            LaunchConfig::default(),
            Some(format!("config read failed: {err}")),
        ),
    }
}

pub fn default_config_text() -> String {
    serde_json::to_string_pretty(&LaunchConfig::default()).unwrap_or_else(|_| "{}".into()) + "\n"
}

pub fn ensure_default_config() -> Result<(), String> {
    let path = config_path();
    if path.exists() {
        return Ok(());
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| format!("create config dir: {err}"))?;
    }
    fs::write(path, default_config_text()).map_err(|err| format!("write config: {err}"))
}

pub fn run_launch(request: LaunchRequest) -> Result<LaunchRecord, String> {
    let (config, config_warning) = load_config();
    let mut detail_parts = Vec::new();
    if let Some(warning) = config_warning {
        detail_parts.push(warning);
    }

    let mut command = resolve_request(&request)?;
    let raw_command = command.argv.join(" ");
    let executable = command.argv.first().map(String::as_str);
    let rule = matching_rule(&config, &request, executable, &raw_command).cloned();
    if let Some(rule) = &rule {
        apply_rule(&config, &mut command, rule, &mut detail_parts);
    } else if matches!(request, LaunchRequest::Desktop { .. })
        && !(config.allow_nvidia_env && nvidia_available())
    {
        prefer_desktop_launcher(&mut command);
    } else if config.allow_nvidia_env && nvidia_available() {
        prepend_env(&mut command, nvidia_env_vars());
    }

    let kind = request_kind(&request).to_string();
    let target = request_target(&request).to_string();
    let argv_for_log = command.argv.clone();
    let boost_ms = rule
        .as_ref()
        .and_then(|rule| rule.launch_boost_ms)
        .unwrap_or(config.default_external_boost_ms);
    let allow_pid_boost = rule
        .as_ref()
        .and_then(|rule| rule.allow_external_pid_boost)
        .unwrap_or(true);

    request_boost(&config, "app-launch", None, boost_ms);

    let spawn = spawn_command(&command, config.isolate_launches);
    let (pid, status, detail) = match spawn {
        Ok(pid_raw) => {
            let launch_pid = normalize_launch_pid(pid_raw);
            if allow_pid_boost {
                request_boost(&config, "app-launch-pid", launch_pid, boost_ms);
            }
            (launch_pid, "ok".to_string(), "spawned".to_string())
        }
        Err(err) => (None, "error".to_string(), err),
    };

    detail_parts.push(detail);
    let record = LaunchRecord {
        timestamp_ms: now_ms(),
        kind,
        target,
        argv: argv_for_log,
        pid,
        status,
        detail: detail_parts.join("; "),
    };
    let _ = append_history(&record, config.history_limit);
    if record.status == "ok" {
        Ok(record)
    } else {
        Err(record.detail)
    }
}

pub fn run_launch_via_daemon(request: LaunchRequest) -> Result<LaunchRecord, String> {
    match send_launch_request(&request) {
        Ok(record) => Ok(record),
        Err(LaunchdError::Connect) => run_launch(request),
        Err(LaunchdError::Request(err)) => Err(err),
    }
}

pub fn serve_launchd() -> Result<(), String> {
    let path = launchd_socket_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| format!("create launchd socket dir: {err}"))?;
    }
    let _ = fs::remove_file(&path);
    let listener =
        UnixListener::bind(&path).map_err(|err| format!("bind launchd socket: {err}"))?;
    let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));

    for stream in listener.incoming() {
        match stream {
            Ok(mut stream) => {
                thread::spawn(move || {
                    let response = handle_launchd_stream(&mut stream);
                    let text = serde_json::to_string(&response).unwrap_or_else(|_| {
                        "{\"ok\":false,\"error\":\"serialization failed\"}".into()
                    });
                    let _ = writeln!(stream, "{text}");
                });
            }
            Err(err) => eprintln!("[astrea-launchd] accept failed: {err}"),
        }
    }
    Ok(())
}

pub fn resolve_request(request: &LaunchRequest) -> Result<CommandSpec, String> {
    match request {
        LaunchRequest::Desktop { id } => {
            let path = resolve_desktop_entry(id)
                .ok_or_else(|| format!("desktop entry not found: {id}"))?;
            command_from_desktop_file(&path)
        }
        LaunchRequest::Command { command } => Ok(CommandSpec {
            argv: vec!["sh".into(), "-lc".into(), command.clone()],
            working_dir: None,
            desktop_file: None,
        }),
        LaunchRequest::Argv { argv, working_dir } => {
            if argv.is_empty() || argv.first().is_some_and(|arg| arg.is_empty()) {
                return Err("argv launch request requires a program".into());
            }
            Ok(CommandSpec {
                argv: argv.clone(),
                working_dir: working_dir
                    .as_deref()
                    .filter(|value| !value.is_empty())
                    .map(expand_home)
                    .map(PathBuf::from),
                desktop_file: None,
            })
        }
        LaunchRequest::File { path } => Ok(CommandSpec {
            argv: command_for_file_path(&expand_home(path))?,
            working_dir: working_dir_for_file(path),
            desktop_file: None,
        }),
        LaunchRequest::Url { url } => {
            validate_url(url)?;
            Ok(CommandSpec {
                argv: vec!["xdg-open".into(), url.clone()],
                working_dir: None,
                desktop_file: None,
            })
        }
        LaunchRequest::Steam { uri } => {
            validate_steam_uri(uri)?;
            let launcher = if command_available("steam") {
                "steam"
            } else {
                "xdg-open"
            };
            Ok(CommandSpec {
                argv: vec![launcher.into(), uri.clone()],
                working_dir: None,
                desktop_file: None,
            })
        }
    }
}

pub fn command_from_desktop_file(path: &Path) -> Result<CommandSpec, String> {
    let entry = parse_desktop_entry(path)?;
    if entry
        .get("Type")
        .map(String::as_str)
        .unwrap_or("Application")
        != "Application"
    {
        return Err("desktop entry is not an application".into());
    }
    if entry.get("Hidden").is_some_and(|v| truthy(v))
        || entry.get("NoDisplay").is_some_and(|v| truthy(v))
    {
        return Err("desktop entry is hidden".into());
    }
    let exec = entry
        .get("Exec")
        .ok_or_else(|| "desktop entry has no Exec".to_string())?;
    let argv = parse_exec_line(exec)?;
    if argv.is_empty() {
        return Err("desktop Exec is empty".into());
    }
    Ok(CommandSpec {
        argv,
        working_dir: entry
            .get("Path")
            .filter(|v| !v.is_empty())
            .map(PathBuf::from),
        desktop_file: Some(path.to_path_buf()),
    })
}

/// Parses a Desktop Entry `Exec` string into argv without shell evaluation.
///
/// Desktop field codes that need external context (`%f`, `%F`, `%u`, `%U`,
/// `%i`, `%c`, and `%k`) are intentionally removed instead of expanded.
/// Literal `%%`, quoting, escaped characters, and explicit quoted empty
/// arguments are preserved.
pub fn parse_exec_line(line: &str) -> Result<Vec<String>, String> {
    let mut args = Vec::new();
    let mut current = String::new();
    let mut chars = line.chars().peekable();
    let mut quote: Option<char> = None;
    let mut arg_started = false;
    let mut suppress_arg = false;

    while let Some(ch) = chars.next() {
        match ch {
            '\'' | '"' if quote.is_none() => {
                quote = Some(ch);
                arg_started = true;
            }
            '\'' | '"' if quote == Some(ch) => {
                quote = None;
                arg_started = true;
            }
            '\\' => {
                if let Some(next) = chars.next() {
                    current.push(next);
                    arg_started = true;
                    suppress_arg = false;
                }
            }
            '%' => {
                arg_started = true;
                match chars.next() {
                    Some('%') => {
                        current.push('%');
                        suppress_arg = false;
                    }
                    Some(code) if "fFuUick".contains(code) => {
                        if current.is_empty() {
                            suppress_arg = true;
                        }
                    }
                    Some(_) | None => {}
                }
            }
            ch if ch.is_whitespace() && quote.is_none() => {
                finish_exec_arg(&mut args, &mut current, &mut arg_started, &mut suppress_arg);
            }
            _ => {
                current.push(ch);
                arg_started = true;
                suppress_arg = false;
            }
        }
    }

    if quote.is_some() {
        return Err("unterminated quote in Exec".into());
    }
    finish_exec_arg(&mut args, &mut current, &mut arg_started, &mut suppress_arg);
    Ok(args)
}

fn finish_exec_arg(
    args: &mut Vec<String>,
    current: &mut String,
    arg_started: &mut bool,
    suppress_arg: &mut bool,
) {
    if *arg_started && !*suppress_arg {
        args.push(std::mem::take(current));
    } else {
        current.clear();
    }
    *arg_started = false;
    *suppress_arg = false;
}

pub fn matching_rule<'a>(
    config: &'a LaunchConfig,
    request: &LaunchRequest,
    executable: Option<&str>,
    command_text: &str,
) -> Option<&'a Rule> {
    let desktop_id = match request {
        LaunchRequest::Desktop { id } => Some(
            Path::new(id)
                .file_name()
                .and_then(|v| v.to_str())
                .unwrap_or(id.as_str()),
        ),
        _ => None,
    };
    let steam_appid = match request {
        LaunchRequest::Steam { uri } => extract_steam_appid(uri),
        LaunchRequest::Url { url } => extract_steam_appid(url),
        LaunchRequest::Argv { .. } => None,
        _ => None,
    };

    config.rules.iter().find(|rule| {
        rule.desktop_id
            .as_deref()
            .zip(desktop_id)
            .is_some_and(|(rule_id, id)| rule_id == id || rule_id == request_target(request))
            || rule
                .executable
                .as_deref()
                .zip(executable)
                .is_some_and(|(needle, exe)| executable_matches(needle, exe))
            || rule
                .command_substring
                .as_deref()
                .is_some_and(|needle| command_text.contains(needle))
            || rule
                .steam_appid
                .as_deref()
                .zip(steam_appid.as_deref())
                .is_some_and(|(needle, appid)| needle == appid)
    })
}

pub fn extract_steam_appid(uri: &str) -> Option<String> {
    let text = uri.trim();
    if let Some(rest) = text.strip_prefix("steam://rungameid/") {
        return rest
            .split(['/', '?', '&'])
            .next()
            .filter(|v| v.chars().all(char::is_numeric))
            .map(str::to_string);
    }
    if let Some(index) = text.find("/app/") {
        let rest = &text[index + 5..];
        return rest
            .split(['/', '?', '&'])
            .next()
            .filter(|v| v.chars().all(char::is_numeric))
            .map(str::to_string);
    }
    None
}

pub fn append_history(record: &LaunchRecord, limit: usize) -> Result<(), String> {
    let path = history_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| format!("create history dir: {err}"))?;
    }
    let line = serde_json::to_string(record).map_err(|err| format!("history json: {err}"))?;
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|err| format!("open history: {err}"))?;
    writeln!(file, "{line}").map_err(|err| format!("write history: {err}"))?;
    trim_history(&path, limit);
    Ok(())
}

pub fn read_history(limit: usize) -> Vec<String> {
    let text = fs::read_to_string(history_path()).unwrap_or_default();
    let mut lines: Vec<String> = text.lines().map(str::to_string).collect();
    if lines.len() > limit {
        lines = lines.split_off(lines.len() - limit);
    }
    lines
}

fn send_launch_request(request: &LaunchRequest) -> Result<LaunchRecord, LaunchdError> {
    let path = launchd_socket_path();
    let mut stream = UnixStream::connect(&path).map_err(|_err| LaunchdError::Connect)?;
    stream
        .set_read_timeout(Some(Duration::from_secs(3)))
        .map_err(|err| LaunchdError::Request(format!("set launchd read timeout: {err}")))?;
    stream
        .set_write_timeout(Some(Duration::from_secs(1)))
        .map_err(|err| LaunchdError::Request(format!("set launchd write timeout: {err}")))?;
    let text = serde_json::to_string(request)
        .map_err(|err| LaunchdError::Request(format!("request json: {err}")))?;
    writeln!(stream, "{text}")
        .map_err(|err| LaunchdError::Request(format!("write launchd request: {err}")))?;
    stream
        .shutdown(Shutdown::Write)
        .map_err(|err| LaunchdError::Request(format!("finish launchd request: {err}")))?;
    let mut response = String::new();
    stream
        .read_to_string(&mut response)
        .map_err(|err| LaunchdError::Request(format!("read launchd response: {err}")))?;
    let response: LaunchDaemonResponse = serde_json::from_str(&response)
        .map_err(|err| LaunchdError::Request(format!("parse launchd response: {err}")))?;
    if response.ok {
        response
            .record
            .ok_or_else(|| LaunchdError::Request("launchd returned empty success".into()))
    } else {
        Err(LaunchdError::Request(
            response.error.unwrap_or_else(|| "launchd failed".into()),
        ))
    }
}

fn handle_launchd_stream(stream: &mut UnixStream) -> LaunchDaemonResponse {
    let mut text = String::new();
    if let Err(err) = stream.read_to_string(&mut text) {
        return LaunchDaemonResponse {
            ok: false,
            record: None,
            error: Some(format!("read request: {err}")),
        };
    }
    let request = match serde_json::from_str::<LaunchRequest>(text.trim()) {
        Ok(request) => request,
        Err(err) => {
            return LaunchDaemonResponse {
                ok: false,
                record: None,
                error: Some(format!("parse request: {err}")),
            };
        }
    };
    match run_launch(request) {
        Ok(record) => LaunchDaemonResponse {
            ok: true,
            record: Some(record),
            error: None,
        },
        Err(err) => LaunchDaemonResponse {
            ok: false,
            record: None,
            error: Some(err),
        },
    }
}

fn apply_rule(
    config: &LaunchConfig,
    command: &mut CommandSpec,
    rule: &Rule,
    details: &mut Vec<String>,
) {
    if let Some(dir) = &rule.working_dir {
        command.working_dir = Some(PathBuf::from(expand_home(dir)));
    }

    prepend_env(command, rule.env.clone());

    let wants_nvidia =
        rule.nvidia_env.unwrap_or(false) || (config.allow_nvidia_env && nvidia_available());
    if wants_nvidia {
        prepend_env(command, nvidia_env_vars());
    }

    if let Some(preset) = &rule.steam_compat_preset {
        apply_steam_compat(command, preset);
        details.push(format!("steam compat preset: {preset}"));
    }

    if let Some(preset) = &rule.game_mode_preset {
        apply_game_mode(command, preset);
        details.push(format!("game mode preset: {preset}"));
    }
}

fn prefer_desktop_launcher(command: &mut CommandSpec) {
    let Some(path) = command.desktop_file.as_ref() else {
        return;
    };
    if command_available("gio") {
        command.argv = vec![
            "gio".into(),
            "launch".into(),
            path.to_string_lossy().to_string(),
        ];
        command.working_dir = None;
    }
}

fn apply_game_mode(command: &mut CommandSpec, preset: &str) {
    match preset {
        "gamemode" if command_available("gamemoderun") => {
            command.argv.insert(0, "gamemoderun".into())
        }
        "gamescope" if command_available("gamescope") => {
            let mut next = vec!["gamescope".into(), "--".into()];
            next.extend(command.argv.clone());
            command.argv = next;
        }
        "gamescope-gamemode" => {
            let mut next = Vec::new();
            if command_available("gamemoderun") {
                next.push("gamemoderun".into());
            }
            if command_available("gamescope") {
                next.extend(["gamescope".into(), "--".into()]);
            }
            next.extend(command.argv.clone());
            command.argv = next;
        }
        _ => {}
    }
}

fn apply_steam_compat(command: &mut CommandSpec, preset: &str) {
    if preset.is_empty() || preset == "default" {
        return;
    }
    prepend_env(command, vec![("STEAM_COMPAT_CONFIG".into(), preset.into())]);
}

fn prepend_env(command: &mut CommandSpec, vars: Vec<(String, String)>) {
    if vars.is_empty() {
        return;
    }
    let mut next = vec!["env".to_string()];
    for (key, value) in vars {
        if !key.is_empty() {
            next.push(format!("{key}={value}"));
        }
    }
    next.extend(command.argv.clone());
    command.argv = next;
}

fn spawn_command(command: &CommandSpec, isolate_launches: bool) -> Result<u32, String> {
    spawn_command_with(
        command,
        isolate_launches,
        command_available("systemd-run"),
        spawn_command_systemd,
        spawn_command_direct,
    )
}

fn spawn_command_with<FSystemd, FDirect>(
    command: &CommandSpec,
    isolate_launches: bool,
    systemd_available: bool,
    systemd_spawn: FSystemd,
    direct_spawn: FDirect,
) -> Result<u32, String>
where
    FSystemd: Fn(&CommandSpec) -> Result<u32, String>,
    FDirect: Fn(&CommandSpec) -> Result<u32, String>,
{
    if isolate_launches && systemd_available {
        match systemd_spawn(command) {
            Ok(pid) => return Ok(pid),
            Err(_) => return direct_spawn(command),
        }
    }
    direct_spawn(command)
}

fn spawn_command_direct(command: &CommandSpec) -> Result<u32, String> {
    let Some(program) = command.argv.first() else {
        return Err("empty command".into());
    };
    let mut process = Command::new(program);
    process.args(&command.argv[1..]);
    process.process_group(0);
    if let Some(dir) = &command.working_dir {
        process.current_dir(dir);
    }
    process
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    process
        .spawn()
        .map(|mut child| {
            let pid = child.id();
            thread::spawn(move || {
                let _ = child.wait();
            });
            pid
        })
        .map_err(|err| format!("spawn failed: {err}"))
}

fn spawn_command_systemd(command: &CommandSpec) -> Result<u32, String> {
    let Some(program) = command.argv.first() else {
        return Err("empty command".into());
    };
    let unit = transient_launch_unit_name();
    let args = systemd_run_args(command, &unit);
    let status = Command::new("systemd-run")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|err| format!("systemd-run failed: {err}"))?;
    if !status.success() {
        return Err(format!("systemd-run exited with {status}"));
    }

    let pid = wait_for_unit_main_pid(&unit).unwrap_or(0);
    if pid == 0 {
        // systemd-run --no-block can succeed before MainPID is visible;
        // treat launch as accepted and return a sentinel pid.
        return Ok(0);
    }
    if program.is_empty() {
        return Err("empty command".into());
    }
    Ok(pid)
}

fn systemd_run_args(command: &CommandSpec, unit: &str) -> Vec<String> {
    let mut args = vec![
        "--user".into(),
        "--collect".into(),
        "--quiet".into(),
        "--no-block".into(),
        format!("--unit={unit}"),
        "--property=ExitType=cgroup".into(),
        "--property=Slice=app.slice".into(),
    ];
    if let Some(dir) = &command.working_dir {
        args.push(format!("--working-directory={}", dir.to_string_lossy()));
    }
    args.push("--".into());
    args.extend(command.argv.clone());
    args
}

fn transient_launch_unit_name() -> String {
    format!("astrea-launch-{}-{}.service", process::id(), now_ms())
}

fn wait_for_unit_main_pid(unit: &str) -> Option<u32> {
    for _ in 0..10 {
        if let Some(pid) = unit_main_pid(unit) {
            if pid > 0 {
                return Some(pid);
            }
        }
        thread::sleep(Duration::from_millis(20));
    }
    None
}

fn unit_main_pid(unit: &str) -> Option<u32> {
    let output = Command::new("systemctl")
        .args(["--user", "show", unit, "--property=MainPID", "--value"])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8_lossy(&output.stdout)
        .trim()
        .parse::<u32>()
        .ok()
}


fn normalize_launch_pid(pid: u32) -> Option<u32> {
    if pid == 0 {
        None
    } else {
        Some(pid)
    }
}

fn request_boost(config: &LaunchConfig, reason: &str, pid: Option<u32>, duration_ms: u64) {
    if !config.latency.enabled {
        return;
    }
    let payload = serde_json::json!({
        "op": "boost",
        "reason": reason,
        "pid": pid,
        "duration_ms": duration_ms,
        "source": "astrea-launch"
    });
    let text = payload.to_string();

    for socket in &config.latency.socket_paths {
        let path = PathBuf::from(expand_home(socket));
        if !path.exists() {
            continue;
        }
        if let Ok(mut stream) = UnixStream::connect(&path) {
            let _ = writeln!(stream, "{text}");
            return;
        }
    }

    if let Some(command) = &config.latency.command {
        if let Some(program) = command.first() {
            let mut child = Command::new(program);
            for arg in &command[1..] {
                child.arg(
                    arg.replace("{reason}", reason)
                        .replace("{duration_ms}", &duration_ms.to_string())
                        .replace("{pid}", &pid.map(|p| p.to_string()).unwrap_or_default()),
                );
            }
            let _ = child
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn();
        }
    }
}

fn parse_desktop_entry(path: &Path) -> Result<std::collections::BTreeMap<String, String>, String> {
    let text = fs::read_to_string(path).map_err(|err| format!("read desktop file: {err}"))?;
    let mut in_entry = false;
    let mut values = std::collections::BTreeMap::new();
    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') && line.ends_with(']') {
            in_entry = line == "[Desktop Entry]";
            continue;
        }
        if !in_entry {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            values.insert(key.trim().to_string(), value.trim().to_string());
        }
    }
    Ok(values)
}

fn resolve_desktop_entry(id: &str) -> Option<PathBuf> {
    let expanded = PathBuf::from(expand_home(id));
    if expanded.is_file() {
        return Some(expanded);
    }

    let file_name = if id.ends_with(".desktop") {
        id.to_string()
    } else {
        format!("{id}.desktop")
    };
    application_dirs()
        .into_iter()
        .chain([xdg_desktop_dir()])
        .map(|dir| dir.join(&file_name))
        .find(|path| path.is_file())
}

fn application_dirs() -> Vec<PathBuf> {
    let mut dirs = vec![xdg_data_home().join("applications")];
    for entry in env::var("XDG_DATA_DIRS")
        .unwrap_or_else(|_| "/usr/local/share:/usr/share".into())
        .split(':')
    {
        if !entry.is_empty() {
            dirs.push(PathBuf::from(entry).join("applications"));
        }
    }
    dirs
}

fn xdg_config_home() -> PathBuf {
    env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".config"))
}

fn xdg_data_home() -> PathBuf {
    env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/share"))
}

fn xdg_state_home() -> PathBuf {
    env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/state"))
}

fn xdg_runtime_dir() -> Option<PathBuf> {
    env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from)
}

fn xdg_desktop_dir() -> PathBuf {
    let config = xdg_config_home().join("user-dirs.dirs");
    if let Ok(text) = fs::read_to_string(config) {
        for line in text.lines() {
            let line = line.trim();
            if let Some(value) = line.strip_prefix("XDG_DESKTOP_DIR=") {
                return PathBuf::from(expand_home(value.trim().trim_matches('"')));
            }
        }
    }
    home_dir().join("Desktop")
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn default_latency_socket_paths() -> Vec<String> {
    let mut paths = Vec::new();
    if let Some(runtime) = xdg_runtime_dir() {
        paths.push(
            runtime
                .join("Astrea/astrea-latencyd.sock")
                .to_string_lossy()
                .to_string(),
        );
        paths.push(
            runtime
                .join("astrea-latencyd.sock")
                .to_string_lossy()
                .to_string(),
        );
    }
    paths.push("/tmp/astrea-latencyd.sock".into());
    paths
}

fn trim_history(path: &Path, limit: usize) {
    if limit == 0 {
        return;
    }
    let Ok(text) = fs::read_to_string(path) else {
        return;
    };
    let lines: Vec<&str> = text.lines().collect();
    if lines.len() <= limit {
        return;
    }
    let keep = lines[lines.len() - limit..].join("\n") + "\n";
    let _ = fs::write(path, keep);
}

fn validate_url(url: &str) -> Result<(), String> {
    let Some((scheme, _)) = url.split_once(':') else {
        return Err("unsupported url scheme".into());
    };
    if !scheme.is_empty()
        && scheme
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '+' | '-' | '.'))
        && scheme
            .chars()
            .next()
            .is_some_and(|ch| ch.is_ascii_alphabetic())
    {
        Ok(())
    } else {
        Err("unsupported url scheme".into())
    }
}

fn validate_steam_uri(uri: &str) -> Result<(), String> {
    if uri.starts_with("steam://")
        || uri.starts_with("https://store.steampowered.com/")
        || uri.starts_with("https://steamcommunity.com/")
    {
        Ok(())
    } else {
        Err("unsupported Steam URI".into())
    }
}

fn executable_matches(needle: &str, executable: &str) -> bool {
    let exe_name = Path::new(executable)
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or(executable);
    needle == executable || needle == exe_name || executable.contains(needle)
}

fn command_available(name: &str) -> bool {
    if name.contains('/') {
        return Path::new(name).is_file();
    }
    env::var_os("PATH")
        .and_then(|paths| {
            env::split_paths(&paths)
                .map(|dir| dir.join(name))
                .find(|path| path.is_file())
        })
        .is_some()
}

fn command_for_file_path(path: &str) -> Result<Vec<String>, String> {
    let target = Path::new(path);
    if target.extension().and_then(|v| v.to_str()) == Some("desktop") && target.is_file() {
        return Ok(command_from_desktop_file(target)?.argv);
    }
    if is_shell_script(target) {
        return Ok(
            terminal_command_for_script(path).unwrap_or_else(|| vec!["sh".into(), path.into()])
        );
    }
    if is_direct_executable(target) {
        return Ok(vec![path.into()]);
    }
    Ok(vec!["xdg-open".into(), path.into()])
}

fn working_dir_for_file(path: &str) -> Option<PathBuf> {
    let target = PathBuf::from(expand_home(path));
    if is_direct_executable(&target) || is_shell_script(&target) {
        return target.parent().map(Path::to_path_buf);
    }
    None
}

fn is_shell_script(path: &Path) -> bool {
    path.extension()
        .and_then(|v| v.to_str())
        .is_some_and(|ext| ext.eq_ignore_ascii_case("sh"))
}

fn is_direct_executable(path: &Path) -> bool {
    if !path.is_file() {
        return false;
    }
    let name = path
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or_default();
    let known_exec_ext = [".appimage", ".run", ".bin", ".elf", ".x86_64", ".bundle"]
        .iter()
        .any(|suffix| name.to_ascii_lowercase().ends_with(suffix));
    let no_extension = !name.contains('.');
    if !known_exec_ext && !no_extension {
        return false;
    }
    let Ok(bytes) = fs::read(path) else {
        return false;
    };
    bytes.starts_with(b"\x7fELF") || bytes.starts_with(b"#!")
}

fn terminal_command_for_script(path: &str) -> Option<Vec<String>> {
    let script = expand_home(path);
    let dir = Path::new(&script)
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(home_dir);
    let inner = format!(
        "cd -- '{}' && sh '{}'",
        shell_quote(&dir.to_string_lossy()),
        shell_quote(&script)
    );
    if command_available("xdg-terminal-exec") {
        return Some(vec![
            "xdg-terminal-exec".into(),
            "sh".into(),
            "-lc".into(),
            inner,
        ]);
    }
    for terminal in [
        "x-terminal-emulator",
        "kitty",
        "foot",
        "ghostty",
        "alacritty",
    ] {
        if command_available(terminal) {
            return Some(vec![
                terminal.into(),
                "-e".into(),
                "sh".into(),
                "-lc".into(),
                inner,
            ]);
        }
    }
    None
}

fn shell_quote(value: &str) -> String {
    value.replace('\'', "'\"'\"'")
}

fn nvidia_available() -> bool {
    Path::new("/proc/driver/nvidia/version").exists() || command_available("nvidia-smi")
}

fn nvidia_env_vars() -> Vec<(String, String)> {
    vec![
        ("__GL_THREADED_OPTIMIZATIONS".into(), "1".into()),
        ("__GL_SHADER_DISK_CACHE".into(), "1".into()),
        ("__GLX_VENDOR_LIBRARY_NAME".into(), "nvidia".into()),
    ]
}

fn expand_home(value: &str) -> String {
    if value == "~" || value == "$HOME" {
        return home_dir().to_string_lossy().to_string();
    }
    if let Some(rest) = value.strip_prefix("~/") {
        return home_dir().join(rest).to_string_lossy().to_string();
    }
    if let Some(rest) = value.strip_prefix("$HOME/") {
        return home_dir().join(rest).to_string_lossy().to_string();
    }
    value.to_string()
}

fn request_kind(request: &LaunchRequest) -> &'static str {
    match request {
        LaunchRequest::Desktop { .. } => "desktop",
        LaunchRequest::Command { .. } => "command",
        LaunchRequest::Argv { .. } => "argv",
        LaunchRequest::File { .. } => "file",
        LaunchRequest::Url { .. } => "url",
        LaunchRequest::Steam { .. } => "steam",
    }
}

fn request_target(request: &LaunchRequest) -> &str {
    match request {
        LaunchRequest::Desktop { id } => id,
        LaunchRequest::Command { command } => command,
        LaunchRequest::Argv { argv, .. } => argv.first().map(String::as_str).unwrap_or(""),
        LaunchRequest::File { path } => path,
        LaunchRequest::Url { url } => url,
        LaunchRequest::Steam { uri } => uri,
    }
}

fn truthy(value: &str) -> bool {
    matches!(value.to_ascii_lowercase().as_str(), "1" | "true" | "yes")
}

fn now_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn launch_isolation_is_enabled_by_default() {
        assert!(LaunchConfig::default().isolate_launches);
    }

    #[test]
    fn builds_systemd_run_args_for_transient_app_service() {
        let command = CommandSpec {
            argv: vec!["/usr/bin/example".into(), "--flag".into()],
            working_dir: Some(PathBuf::from("/tmp/example")),
            desktop_file: None,
        };

        let args = systemd_run_args(&command, "astrea-launch-test.service");

        assert!(args.contains(&"--user".into()));
        assert!(args.contains(&"--collect".into()));
        assert!(args.contains(&"--no-block".into()));
        assert!(args.contains(&"--property=ExitType=cgroup".into()));
        assert!(args.contains(&"--working-directory=/tmp/example".into()));
        assert_eq!(args.iter().filter(|arg| arg.as_str() == "--").count(), 1);
        assert_eq!(
            &args[args.len() - 3..],
            &[
                "--".to_string(),
                "/usr/bin/example".to_string(),
                "--flag".to_string()
            ]
        );
    }
}


#[cfg(test)]
mod launch_spawn_tests {
    use super::*;
    use std::sync::atomic::{AtomicBool, Ordering};

    fn sample_command() -> CommandSpec {
        CommandSpec {
            argv: vec!["/usr/bin/true".into()],
            working_dir: None,
            desktop_file: None,
        }
    }

    #[test]
    fn systemd_success_with_zero_pid_does_not_fallback_to_direct_spawn() {
        let direct_called = AtomicBool::new(false);
        let result = spawn_command_with(
            &sample_command(),
            true,
            true,
            |_| Ok(0),
            |_| {
                direct_called.store(true, Ordering::SeqCst);
                Ok(42)
            },
        );

        assert_eq!(result.expect("launch accepted"), 0);
        assert!(!direct_called.load(Ordering::SeqCst));
    }

    #[test]
    fn systemd_failure_falls_back_to_direct_spawn() {
        let direct_called = AtomicBool::new(false);
        let result = spawn_command_with(
            &sample_command(),
            true,
            true,
            |_| Err("systemd failed".into()),
            |_| {
                direct_called.store(true, Ordering::SeqCst);
                Ok(99)
            },
        );

        assert_eq!(result.expect("fallback launch"), 99);
        assert!(direct_called.load(Ordering::SeqCst));
    }

    #[test]
    fn zero_pid_is_treated_as_none_for_pid_boosting() {
        assert_eq!(normalize_launch_pid(0), None);
        assert_eq!(normalize_launch_pid(1234), Some(1234));
    }
}
