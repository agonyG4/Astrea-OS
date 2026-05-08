# Astrea - Weather Bridge

Related notes: [[Astrea - Weather App]], [[Astrea - Spotlight]], [[Astrea - Core Bridge]]

## File
`Core/bridge/apps/weather.py`

## Responsibility
Weather CLI backend for the Weather app and Spotlight weather summary.

It also handles Weather-owned INMET notification delivery and Weather notification settings.

## Commands
Observed CLI parser supports:
- `get`
- `hourly`
- `forecast`
- cache clearing
- `notify-alerts`
- `notifications-setting`

Observed output modes:
- full JSON
- summary JSON
- human-readable output

## Consumers
- `Apps/Weather/state/WeatherState.qml`
- `Quickshell/spotlight/Spotlight.qml`

## Notification Behavior
`notify-alerts` receives the current alert list from `WeatherState`.

It:
- checks `~/.local/state/Astrea/weather/settings.json`
- skips delivery when notifications are disabled
- deduplicates delivered alerts through `~/.local/state/Astrea/weather/inmet-notified.json`
- sends desktop notifications with `notify-send`

Only successfully delivered alerts are persisted as notified, so temporary notification failures can retry on a later refresh.

## Dependencies
- `requests`
- external weather APIs
- INMET alerts endpoint
- cache under `~/.cache/weather`
- `notify-send` for desktop notifications
- state under `~/.local/state/Astrea/weather`

## Unknown
The exact external API payloads are time-sensitive and were not revalidated in this structure pass.
