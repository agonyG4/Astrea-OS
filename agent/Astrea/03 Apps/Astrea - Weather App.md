# Astrea - Weather App

Related notes: [[Astrea]], [[Astrea - Weather Bridge]], [[Astrea - Assets and Data]]

## Folder
`Apps/Weather/`

## Main Entry
`Apps/Weather/WeatherApp.qml`

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
- `state/WeatherState.qml`
  - calls [[Astrea - Weather Bridge]].

Weather consumes the shared Astrea theme through:
- `Apps/Weather/AstreaComponents -> Core/components`
- `import "AstreaComponents" as UI`

## Components
- `AstreaComponents`
  - shared text, divider, theme, and generic UI tokens from [[Astrea - Core Components]]
- `components/common/WeatherIcon.qml`
  - Weather-specific condition-to-icon mapping
- `components/sections`
  - Weather-specific screen sections
- `components/utils/WeatherFormat.js`

## Assets
Weather icons live under:
- `Apps/Weather/assets/weather`

## Data Flow
1. `WeatherApp.qml` creates `WeatherState`.
2. `WeatherState` loads the notifications preference with `weather.py notifications-setting`.
3. `WeatherState` calls `weather.py get --json`.
4. Python returns JSON.
5. QML parses the payload.
6. Section components render structured weather data.
7. If INMET alerts are present and notifications are enabled, `WeatherState` calls `weather.py notify-alerts`.
8. A timer refreshes every 30 minutes.
