use std::env;
use std::process;
use std::thread;
use std::time::Duration;
use weather_core::{DEFAULT_INTERVAL_SECONDS, check_and_notify, fetch_weather_json, load_settings};

fn has_flag(args: &[String], flag: &str) -> bool {
    args.iter().any(|arg| arg == flag)
}

fn flag_value(args: &[String], flag: &str) -> Option<String> {
    args.iter()
        .position(|arg| arg == flag)
        .and_then(|idx| args.get(idx + 1))
        .cloned()
}

fn run_once(force: bool, dry_run: bool) -> Result<(), String> {
    let settings = load_settings();
    let city = settings.city;
    let data = fetch_weather_json(&city, force)?;
    let result = check_and_notify(&data, dry_run);
    eprintln!(
        "astrea-weatherd: city={} alerts={} notified={} skipped={} failed={} disabled={}",
        data.get("city")
            .and_then(serde_json::Value::as_str)
            .unwrap_or(&city),
        result.alerts.len(),
        result.notified,
        result.skipped,
        result.failed,
        result.disabled,
    );
    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let once = has_flag(&args, "--once");
    let force = has_flag(&args, "--force");
    let dry_run = has_flag(&args, "--dry-run");
    let interval = flag_value(&args, "--interval-seconds")
        .and_then(|value| value.parse::<u64>().ok())
        .filter(|value| *value >= 60)
        .unwrap_or(DEFAULT_INTERVAL_SECONDS);

    loop {
        if let Err(err) = run_once(force, dry_run) {
            eprintln!("astrea-weatherd: {err}");
            if once {
                process::exit(1);
            }
        }

        if once {
            break;
        }
        thread::sleep(Duration::from_secs(interval));
    }
}
