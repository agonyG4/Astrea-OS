use serde_json::json;
use std::env;
use std::process;
use weather_core::{
    check_and_notify, fetch_weather_json, load_settings, notify_alert, save_settings, summary_json,
    WeatherAlert, WeatherSettings, DEFAULT_CITY,
};

fn print_json(value: serde_json::Value) {
    println!(
        "{}",
        serde_json::to_string(&value).unwrap_or_else(|_| "{}".to_string())
    );
}

fn usage() -> ! {
    eprintln!(
        "Usage: weather-cli <get|summary|settings|check-alerts|notify-test> [options]\n\
         \n\
         get [city] [--force] [--json]\n\
         summary [city] [--force]\n\
         settings [true|false] [city]\n\
         check-alerts [city] [--force] [--dry-run]\n\
         notify-test"
    );
    process::exit(2);
}

fn has_flag(args: &[String], flag: &str) -> bool {
    args.iter().any(|arg| arg == flag)
}

fn city_arg(args: &[String]) -> String {
    args.iter()
        .find(|arg| !arg.starts_with("--"))
        .cloned()
        .unwrap_or_else(|| load_settings().city)
}

fn parse_bool(value: &str) -> Option<bool> {
    match value.to_ascii_lowercase().as_str() {
        "1" | "true" | "yes" | "on" | "sim" | "enabled" => Some(true),
        "0" | "false" | "no" | "off" | "nao" | "não" | "disabled" => Some(false),
        _ => None,
    }
}

fn main() {
    let mut args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        usage();
    }

    let command = args.remove(0);
    let result = match command.as_str() {
        "get" => {
            let city = city_arg(&args);
            fetch_weather_json(&city, has_flag(&args, "--force")).map(|data| {
                if has_flag(&args, "--json") {
                    data
                } else {
                    data
                }
            })
        }
        "summary" => {
            let city = city_arg(&args);
            fetch_weather_json(&city, has_flag(&args, "--force")).map(|data| summary_json(&data))
        }
        "settings" => {
            let mut settings = load_settings();
            let should_save = !args.is_empty();
            if should_save {
                if let Some(enabled) = args.first().and_then(|value| parse_bool(value)) {
                    settings.notifications_enabled = enabled;
                }
                if let Some(city) = args.get(1) {
                    settings.city = city.clone();
                } else if settings.city.trim().is_empty() {
                    settings.city = DEFAULT_CITY.to_string();
                }
            }
            if should_save {
                if let Err(err) = save_settings(&WeatherSettings {
                    schema_version: 1,
                    notifications_enabled: settings.notifications_enabled,
                    city: settings.city.clone(),
                }) {
                    eprintln!("{err}");
                    process::exit(1);
                }
            }
            Ok(serde_json::to_value(settings).unwrap_or_else(|_| json!({})))
        }
        "check-alerts" => {
            let city = city_arg(&args);
            fetch_weather_json(&city, has_flag(&args, "--force")).map(|data| {
                serde_json::to_value(check_and_notify(&data, has_flag(&args, "--dry-run")))
                    .unwrap_or_else(|_| json!({}))
            })
        }
        "notify-test" => {
            let alert = WeatherAlert::new(
                "test",
                "Astrea Weather",
                "Weather notifications are running.",
                "normal",
            );
            Ok(json!({
                "sent": notify_alert(&alert, has_flag(&args, "--dry-run")),
                "dry_run": has_flag(&args, "--dry-run")
            }))
        }
        _ => usage(),
    };

    match result {
        Ok(value) => print_json(value),
        Err(err) => {
            eprintln!("{err}");
            process::exit(1);
        }
    }
}
