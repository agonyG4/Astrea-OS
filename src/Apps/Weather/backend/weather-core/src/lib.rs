use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, HashSet};
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub const DEFAULT_CITY: &str = "Itajaí";
pub const DEFAULT_INTERVAL_SECONDS: u64 = 30 * 60;
pub const CACHE_MAX_AGE_SECONDS: u64 = 35 * 60;
pub const SEEN_TTL_SECONDS: u64 = 14 * 24 * 60 * 60;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct WeatherAlert {
    pub id: String,
    pub kind: String,
    pub title: String,
    pub body: String,
    pub urgency: String,
}

impl WeatherAlert {
    pub fn new(kind: &str, title: &str, body: &str, urgency: &str) -> Self {
        let mut alert = Self {
            id: String::new(),
            kind: kind.to_string(),
            title: title.to_string(),
            body: body.to_string(),
            urgency: urgency.to_string(),
        };
        alert.id = stable_id(&[&alert.kind, &alert.title, &alert.body, &alert.urgency]);
        alert
    }
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct AlertState {
    #[serde(default)]
    pub schema_version: u8,
    #[serde(default)]
    pub seen: BTreeMap<String, u64>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct WeatherSettings {
    pub schema_version: u8,
    pub notifications_enabled: bool,
    pub city: String,
}

impl Default for WeatherSettings {
    fn default() -> Self {
        Self {
            schema_version: 1,
            notifications_enabled: true,
            city: DEFAULT_CITY.to_string(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct CheckResult {
    pub alerts: Vec<WeatherAlert>,
    pub notified: usize,
    pub skipped: usize,
    pub failed: usize,
    pub disabled: bool,
    pub dry_run: bool,
    pub notifier_available: bool,
}

pub fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/home/agony"))
}

pub fn astrea_root() -> PathBuf {
    env::var_os("ASTREA_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/share/Astrea"))
}

pub fn state_dir() -> PathBuf {
    env::var_os("ASTREA_WEATHER_STATE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/state/Astrea/weather"))
}

pub fn current_cache_path() -> PathBuf {
    state_dir().join("current.json")
}

pub fn settings_path() -> PathBuf {
    env::var_os("ASTREA_WEATHER_SETTINGS_STATE")
        .map(PathBuf::from)
        .unwrap_or_else(|| state_dir().join("settings.json"))
}

pub fn alert_state_path() -> PathBuf {
    env::var_os("ASTREA_WEATHER_NOTIFY_STATE")
        .map(PathBuf::from)
        .unwrap_or_else(|| state_dir().join("alerts-seen.json"))
}

pub fn weather_py_path() -> PathBuf {
    env::var_os("ASTREA_WEATHER_PY")
        .map(PathBuf::from)
        .unwrap_or_else(|| astrea_root().join("Core/bridge/apps/weather.py"))
}

pub fn astrea_notify_path() -> PathBuf {
    env::var_os("ASTREA_NOTIFY")
        .map(PathBuf::from)
        .unwrap_or_else(|| astrea_root().join("System/services/astrea_notify.py"))
}

pub fn now_unix() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or(Duration::from_secs(0))
        .as_secs()
}

pub fn load_json(path: PathBuf) -> Option<Value> {
    let text = fs::read_to_string(path).ok()?;
    serde_json::from_str(&text).ok()
}

pub fn write_json_atomic(path: PathBuf, value: &Value) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, serde_json::to_vec(value)?)?;
    fs::rename(tmp, path)?;
    Ok(())
}

pub fn load_settings() -> WeatherSettings {
    let Some(value) = load_json(settings_path()) else {
        return WeatherSettings::default();
    };
    WeatherSettings {
        schema_version: value
            .get("schema_version")
            .and_then(Value::as_u64)
            .unwrap_or(1) as u8,
        notifications_enabled: value
            .get("notifications_enabled")
            .and_then(Value::as_bool)
            .unwrap_or(true),
        city: value
            .get("city")
            .and_then(Value::as_str)
            .filter(|city| !city.trim().is_empty())
            .unwrap_or(DEFAULT_CITY)
            .to_string(),
    }
}

pub fn save_settings(settings: &WeatherSettings) -> io::Result<()> {
    write_json_atomic(settings_path(), &serde_json::to_value(settings)?)
}

pub fn load_alert_state() -> AlertState {
    load_json(alert_state_path())
        .and_then(|value| serde_json::from_value(value).ok())
        .unwrap_or_default()
}

pub fn save_alert_state(state: &AlertState) -> io::Result<()> {
    write_json_atomic(alert_state_path(), &serde_json::to_value(state)?)
}

pub fn cached_current(max_age_seconds: u64) -> Option<Value> {
    let path = current_cache_path();
    let age = fs::metadata(&path)
        .and_then(|meta| meta.modified())
        .ok()
        .and_then(|modified| modified.elapsed().ok())?;
    if age.as_secs() > max_age_seconds {
        return None;
    }
    load_json(path)
}

pub fn fetch_weather_json(city: &str, force: bool) -> Result<Value, String> {
    if !force {
        if let Some(cached) = cached_current(CACHE_MAX_AGE_SECONDS) {
            return Ok(cached);
        }
    }

    let mut command = Command::new("/usr/bin/env");
    command
        .arg("python3")
        .arg(weather_py_path())
        .arg("get")
        .arg(city)
        .arg("--json")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if force {
        command.arg("--force");
    }

    let output = command
        .output()
        .map_err(|err| format!("failed to run weather backend: {err}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        return Err(if stderr.is_empty() {
            "weather backend failed".to_string()
        } else {
            stderr
        });
    }

    let data: Value = serde_json::from_slice(&output.stdout)
        .map_err(|err| format!("weather backend returned invalid json: {err}"))?;
    let _ = write_json_atomic(current_cache_path(), &data);
    Ok(data)
}

pub fn evaluate_weather_alerts(data: &Value) -> Vec<WeatherAlert> {
    let mut alerts = Vec::new();
    let city = data.get("city").and_then(Value::as_str).unwrap_or("");

    if let Some(items) = data.get("alerts").and_then(Value::as_array) {
        for item in items {
            let title = item
                .get("title")
                .and_then(Value::as_str)
                .unwrap_or("Aviso meteorológico");
            let source = item.get("source").and_then(Value::as_str).unwrap_or("INMET");
            let severity = item.get("severity").and_then(Value::as_str).unwrap_or("");
            let risks = text_from_value(item.get("risks"));
            let when = match (
                item.get("start").and_then(Value::as_str),
                item.get("end").and_then(Value::as_str),
            ) {
                (Some(start), Some(end)) if !start.is_empty() && !end.is_empty() => {
                    format!(" • {start} até {end}")
                }
                _ => String::new(),
            };
            let body = compact_text(&format!("{city} • {severity}{when} • {risks}"), 260);
            alerts.push(WeatherAlert::new(
                "inmet",
                &format!("{source}: {title}"),
                &body,
                &urgency_from_text(&format!("{severity} {title}")),
            ));
        }
    }

    let condition = lower_text(data.get("condition"));
    if condition.contains("trovoada") || condition.contains("tempest") {
        alerts.push(WeatherAlert::new(
            "storm",
            "Astrea Weather: tempestade",
            &format!("{city}: condição atual indica {condition}"),
            "critical",
        ));
    }

    let temp = number(data.get("temp"));
    let temp_max = number(data.get("temp_max"));
    let temp_min = number(data.get("temp_min"));
    if temp >= 35.0 || temp_max >= 35.0 {
        alerts.push(WeatherAlert::new(
            "heat",
            "Astrea Weather: calor extremo",
            &format!("{city}: temperatura pode chegar a {}°C", temp.max(temp_max).round()),
            "normal",
        ));
    }
    if temp <= 5.0 || temp_min <= 5.0 {
        alerts.push(WeatherAlert::new(
            "cold",
            "Astrea Weather: frio intenso",
            &format!("{city}: temperatura mínima de {}°C", temp.min(temp_min).round()),
            "normal",
        ));
    }

    let wind = number(data.get("wind"));
    let gusts = number(data.get("wind_gusts"));
    if wind >= 45.0 || gusts >= 60.0 {
        alerts.push(WeatherAlert::new(
            "wind",
            "Astrea Weather: vento forte",
            &format!("{city}: rajadas de até {} km/h", gusts.max(wind).round()),
            "normal",
        ));
    }

    if let Some(hourly) = data.get("hourly").and_then(Value::as_array) {
        if let Some(hour) = hourly.iter().take(6).find(|hour| number(hour.get("rain")) >= 70.0) {
            let rain = number(hour.get("rain")).round();
            let time = hour.get("time").and_then(Value::as_str).unwrap_or("");
            alerts.push(WeatherAlert::new(
                "rain",
                "Astrea Weather: chuva forte",
                &format!("{city}: {rain}% de chance de chuva nas próximas horas ({time})"),
                "normal",
            ));
        }
    }

    dedupe_alerts(alerts)
}

pub fn filter_new_alerts(
    state: &mut AlertState,
    alerts: &[WeatherAlert],
    now: u64,
) -> Vec<WeatherAlert> {
    let mut new_alerts = Vec::new();
    let active: HashSet<String> = alerts.iter().map(|alert| alert.id.clone()).collect();

    for alert in alerts {
        if state.seen.contains_key(&alert.id) {
            continue;
        }
        state.seen.insert(alert.id.clone(), now);
        new_alerts.push(alert.clone());
    }

    let cutoff = now.saturating_sub(SEEN_TTL_SECONDS);
    state
        .seen
        .retain(|id, seen_at| active.contains(id) || *seen_at >= cutoff);
    state.schema_version = 1;
    new_alerts
}

pub fn notify_alert(alert: &WeatherAlert, dry_run: bool) -> bool {
    let mut command = Command::new("/usr/bin/env");
    command
        .arg("python3")
        .arg(astrea_notify_path())
        .arg("--app")
        .arg("Astrea Weather")
        .arg("--urgency")
        .arg(&alert.urgency)
        .arg("--icon")
        .arg("weather-severe-alert")
        .arg("--category")
        .arg("weather.alert")
        .arg("--desktop-entry")
        .arg("astrea-weather")
        .arg(&alert.title)
        .arg(&alert.body)
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    if dry_run {
        command.arg("--dry-run");
    }
    command.status().map(|status| status.success()).unwrap_or(false)
}

pub fn check_and_notify(data: &Value, dry_run: bool) -> CheckResult {
    let settings = load_settings();
    let alerts = evaluate_weather_alerts(data);
    let notifier_available = astrea_notify_path().is_file();

    if !settings.notifications_enabled {
        return CheckResult {
            skipped: alerts.len(),
            alerts,
            notified: 0,
            failed: 0,
            disabled: true,
            dry_run,
            notifier_available,
        };
    }

    let mut state = load_alert_state();
    let new_alerts = filter_new_alerts(&mut state, &alerts, now_unix());
    let mut notified = 0;
    let mut failed = 0;

    for alert in &new_alerts {
        if notify_alert(alert, dry_run) {
            notified += 1;
        } else {
            state.seen.remove(&alert.id);
            failed += 1;
        }
    }

    let _ = save_alert_state(&state);
    CheckResult {
        skipped: alerts.len().saturating_sub(new_alerts.len()),
        alerts,
        notified,
        failed,
        disabled: false,
        dry_run,
        notifier_available,
    }
}

pub fn summary_json(data: &Value) -> Value {
    json!({
        "schema_version": data.get("schema_version").and_then(Value::as_i64).unwrap_or_default(),
        "city": data.get("city").and_then(Value::as_str).unwrap_or_default(),
        "state": data.get("state").and_then(Value::as_str).unwrap_or_default(),
        "temp": data.get("temp").and_then(Value::as_i64).unwrap_or_default(),
        "condition": data.get("condition").and_then(Value::as_str).unwrap_or_default(),
        "feels_like": data.get("feels_like").and_then(Value::as_i64).unwrap_or_default(),
        "humidity": data.get("humidity").and_then(Value::as_i64).unwrap_or_default(),
        "stale": data.get("stale").and_then(Value::as_bool).unwrap_or(false),
    })
}

fn stable_id(parts: &[&str]) -> String {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    for part in parts {
        part.hash(&mut hasher);
    }
    format!("{:016x}", hasher.finish())
}

fn dedupe_alerts(alerts: Vec<WeatherAlert>) -> Vec<WeatherAlert> {
    let mut seen = HashSet::new();
    let mut result = Vec::new();
    for alert in alerts {
        if seen.insert(alert.id.clone()) {
            result.push(alert);
        }
    }
    result
}

fn lower_text(value: Option<&Value>) -> String {
    value
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_lowercase()
}

fn number(value: Option<&Value>) -> f64 {
    value.and_then(Value::as_f64).unwrap_or_default()
}

fn text_from_value(value: Option<&Value>) -> String {
    match value {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(Value::as_str)
            .collect::<Vec<_>>()
            .join(" "),
        Some(Value::String(text)) => text.clone(),
        Some(other) => other.to_string(),
        None => String::new(),
    }
}

fn compact_text(text: &str, limit: usize) -> String {
    let compact = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if compact.chars().count() <= limit {
        return compact;
    }
    compact.chars().take(limit.saturating_sub(1)).collect::<String>() + "…"
}

fn urgency_from_text(text: &str) -> String {
    let text = text.to_lowercase();
    if text.contains("grande perigo") || text.contains("vermelho") || text.contains("red") {
        "critical".to_string()
    } else if text.contains("perigo") || text.contains("laranja") || text.contains("orange") {
        "normal".to_string()
    } else {
        "low".to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn builds_alerts_from_rain_storm_temperature_and_inmet_data() {
        let payload = json!({
            "city": "Itajai",
            "temp": 36,
            "temp_max": 37,
            "temp_min": 22,
            "condition": "Trovoada",
            "wind": 28,
            "wind_gusts": 62,
            "hourly": [
                {"time": "14:00", "rain": 80, "cond": "Chuva forte"},
                {"time": "15:00", "rain": 20, "cond": "Limpo"}
            ],
            "alerts": [
                {
                    "title": "Chuvas intensas",
                    "severity": "Perigo",
                    "start": "hoje",
                    "end": "amanha",
                    "risks": ["Risco de alagamentos"],
                    "source": "INMET"
                }
            ]
        });

        let alerts = evaluate_weather_alerts(&payload);
        let kinds: Vec<_> = alerts.iter().map(|alert| alert.kind.as_str()).collect();

        assert!(kinds.contains(&"inmet"));
        assert!(kinds.contains(&"rain"));
        assert!(kinds.contains(&"storm"));
        assert!(kinds.contains(&"heat"));
        assert!(kinds.contains(&"wind"));
    }

    #[test]
    fn dedupe_state_only_delivers_new_alerts() {
        let alerts = vec![
            WeatherAlert::new("rain", "Rain", "Strong rain", "normal"),
            WeatherAlert::new("rain", "Rain", "Strong rain", "normal"),
            WeatherAlert::new("cold", "Cold", "Low temperature", "normal"),
        ];
        let mut state = AlertState::default();

        let first = filter_new_alerts(&mut state, &alerts, 1000);
        let second = filter_new_alerts(&mut state, &alerts, 1001);

        assert_eq!(first.len(), 2);
        assert!(second.is_empty());
    }
}
