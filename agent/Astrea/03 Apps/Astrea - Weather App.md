# Astrea - Weather App

Related notes: [[Astrea]], [[Astrea - Weather Bridge]], [[Astrea - Assets and Data]]

## Folder
`Apps/Weather/`

## Main Entry
`Apps/Weather/WeatherApp.qml`

The root entrypoint is a thin wrapper around:
- `Apps/Weather/ui/WeatherAppView.qml`

## Responsibility
Weather is a visual weather dashboard.

It renders:
- current summary
- alerts
- settings button
- hourly forecast
- weekly forecast
- air quality
- temperature trend
- feels-like information
- day detail sheet
- alert detail sheet

## Settings
Weather has an in-app settings sheet opened from the top-right settings button.

Current options:
- INMET alert notifications on/off.

The notification preference is persisted through [[Astrea - Weather Bridge]] at:
- `~/.local/state/Astrea/weather/settings.json`

## State
- `ui/state/WeatherState.qml`
  - calls [[Astrea - Weather Bridge]].

Weather consumes shared Astrea components through:
- `Apps/Weather/AstreaComponents -> Core/components`
- `import "../AstreaComponents" as UI` from `ui/WeatherAppView.qml`

## Components
- `AstreaComponents`
  - shared text, divider, theme, and generic UI tokens from [[Astrea - Core Components]]
- `ui/components/common/WeatherIcon.qml`
  - Weather-specific condition-to-icon mapping
- `ui/components/sections`
  - Weather-specific screen sections
- `ui/components/utils/WeatherFormat.js`

## Assets
Weather icons live under:
- `Apps/Weather/assets/icons/weather`

## Data Flow
1. `WeatherApp.qml` creates `WeatherState`.
2. `WeatherState` loads the notifications preference with `weather-cli settings`.
3. `WeatherState` calls `weather-cli get --json`.
4. The Rust CLI returns JSON, using the compatibility weather fetcher behind the backend.
5. QML parses the payload.
6. Section components render structured weather data.
7. `astrea-weatherd` handles alert checks, deduplication, cache refresh, and desktop notifications outside the UI lifecycle.

## Backend Missing Behavior
`WeatherState.qml` treats missing `bin/weather-cli` as a backend installation problem and shows a recovery message that points to `astrea-services.sh doctor`.

Do not restore direct QML calls to `Core/bridge/apps/weather.py`; that Python file is the compatibility fetcher behind the Rust CLI contract.
