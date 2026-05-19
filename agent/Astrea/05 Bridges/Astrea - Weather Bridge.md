# Astrea - Weather Bridge

Related notes: [[Astrea - Weather App]], [[Astrea - Spotlight]], [[Astrea - Core Bridge]]

## Files
- `Apps/Weather/backend/weather-core`
- `Apps/Weather/backend/weather-cli`
- `Apps/Weather/backend/weatherd`
- installed binaries: `bin/weather-cli`, `bin/astrea-weatherd`
- legacy compatibility fetcher: `Core/bridge/apps/weather.py`

## Responsibility
Weather backend for the Weather app, Spotlight weather summary, and the
system-wide Weather monitor.

Notification monitoring is owned by `astrea-weatherd`, not by QML.

## Commands
The Rust CLI supports:
- `get`
- `summary`
- `settings`
- `check-alerts`
- `notify-test`

Observed output modes:
- full JSON
- summary JSON

## Consumers
- `Apps/Weather/ui/state/WeatherState.qml`
- `Quickshell/spotlight/Spotlight.qml`
- `astrea-weatherd.service`

## Install And Verify
`System/services/astrea-services.sh install` builds the Weather workspace and installs `weather-cli` plus `astrea-weatherd` into `bin`.

`System/services/astrea-services.sh doctor weather` runs the Weather verification path, including Cargo checks when available.

## Notification Behavior
`astrea-weatherd` periodically fetches weather data and evaluates alert rules
independently from the Weather app lifecycle.

It:
- checks `~/.local/state/Astrea/weather/settings.json`
- caches current weather in `~/.local/state/Astrea/weather/current.json`
- skips notification delivery when notifications are disabled
- deduplicates delivered alerts through `~/.local/state/Astrea/weather/alerts-seen.json`
- sends desktop notifications through `System/services/astrea_notify.py`
- lets Astrea's central `org.freedesktop.Notifications` service own delivery and rendering

Only successfully delivered alerts remain persisted as notified, so temporary
notification failures can retry on a later refresh.

Alert sources include:
- INMET active alerts
- high rain probability in the next hours
- storm/current thunder conditions
- strong wind or gusts
- extreme heat or cold

## Dependencies
- `requests`
- external weather APIs
- INMET alerts endpoint
- cache under `~/.cache/weather`
- cache/state under `~/.local/state/Astrea/weather`
- `System/services/astrea_notify.py` for desktop notification delivery
- `systemd --user`

## Unknown
The exact external API payloads are time-sensitive and were not revalidated in this structure pass.
