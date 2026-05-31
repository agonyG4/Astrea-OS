use serde_json::json;
use std::env;
use std::process;
use weather_core::{
    WeatherAlert, WeatherSettings, check_and_notify, fetch_weather_json, load_settings,
    notify_alert, save_settings, summary_json,
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
         settings [true|false] [city] [--city value|--clear-city]\n\
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

fn flag_value(args: &[String], flag: &str) -> Option<String> {
    args.iter()
        .position(|arg| arg == flag)
        .and_then(|idx| args.get(idx + 1))
        .cloned()
}

fn parse_bool(value: &str) -> Option<bool> {
    match value.to_ascii_lowercase().as_str() {
        "1" | "true" | "yes" | "on" | "sim" | "enabled" => Some(true),
        "0" | "false" | "no" | "off" | "nao" | "não" | "disabled" => Some(false),
        _ => None,
    }
}

fn settings_from_args(mut settings: WeatherSettings, args: &[String]) -> WeatherSettings {
    if let Some(enabled) = flag_value(args, "--notifications")
        .or_else(|| flag_value(args, "--notifications-enabled"))
        .and_then(|value| parse_bool(&value))
    {
        settings.notifications_enabled = enabled;
    } else if let Some(enabled) = args.first().and_then(|value| parse_bool(value)) {
        settings.notifications_enabled = enabled;
    }

    if has_flag(args, "--clear-city") {
        settings.city.clear();
    } else if let Some(city) = flag_value(args, "--city") {
        settings.city = city.trim().to_string();
    } else if let Some(city) = args.get(1) {
        if !city.trim().is_empty() {
            settings.city = city.trim().to_string();
        }
    }

    settings.schema_version = 1;
    settings
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
                settings = settings_from_args(settings, &args);
            }
            if should_save {
                if let Err(err) = save_settings(&settings) {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn settings_flags_update_city_without_changing_notifications() {
        let current = WeatherSettings {
            schema_version: 1,
            notifications_enabled: false,
            city: "Itajaí".to_string(),
        };
        let args = vec!["--city".to_string(), "Paris, France".to_string()];

        let updated = settings_from_args(current, &args);

        assert!(!updated.notifications_enabled);
        assert_eq!(updated.city, "Paris, France");
    }

    #[test]
    fn settings_city_flag_can_clear_saved_city() {
        let current = WeatherSettings {
            schema_version: 1,
            notifications_enabled: true,
            city: "Itajaí".to_string(),
        };
        let args = vec!["--city".to_string(), "".to_string()];

        let updated = settings_from_args(current, &args);

        assert_eq!(updated.city, "");
    }
}
