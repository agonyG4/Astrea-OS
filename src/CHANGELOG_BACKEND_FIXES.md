# Astrea Backend Fixes Changelog

Date: 2026-05-30
Target: `/home/agony/.local/share/Astrea-Rolling`

## Summary

This changelog documents the backend hardening pass applied to the live Astrea runtime. The work focused on validation, timeouts, atomic writes, safer runtime sockets, stale-cache behavior, and rebuilt backend binaries.

## Security And Validation

- Hardened the user profile backend.
- Rejected invalid usernames containing path separators, traversal, newlines, empty values, and unsafe characters.
- Validated SDDM session names before writing autologin config.
- Validated display names for emptiness, excessive length, and control characters.
- Updated the privileged helper at `/usr/local/libexec/astrea-user-profile-helper`.
- Added timeout protection around privileged profile helper calls.

## Portal FileChooser

- Hardened `SaveFiles` filename handling.
- Rejected absolute paths, path traversal, slashes, backslashes, null bytes, and control characters.
- Preserved normal save-file behavior for plain names like `note.txt`.

## Media Viewer

- Changed preview conversion to write into a temporary cache file first.
- Published converted previews with `os.replace` only after successful conversion.
- Added conversion timeouts for `magick`, `convert`, and `ffmpeg` paths.
- Prevented partial or corrupt preview cache files from becoming visible after failed conversion.

## Storage Backend

- Reworked JSON writes to use unique temporary files and atomic replace.
- Preserved unrelated stale `.tmp` files instead of deleting or reusing fixed temp paths.
- Added timeout protection to `StorageSense json`.
- Added timeout protection to the heavy background refresh scan.
- Improved timeout error reporting in refresh status payloads.

## Wallpaper Backend

- Changed user wallpaper import/add flow to use a staging directory.
- Published wallpaper folders only after copy, metadata, and thumbnail generation succeed.
- Prevented broken partial wallpaper folders from appearing in the user library.
- Made active wallpaper symlink updates atomic.

## Desktop App Index

- Made PNG icon installation atomic.
- Made downloaded Steam icon asset writes atomic.
- Made ICO conversion publish atomically.
- Added size limits for downloaded and extracted icon assets.
- Prevented partial icon files from being left behind after failed copy, download, or conversion.

## Network Backend

- Replaced fragile IPv4 regex validation with `ipaddress` validation.
- Added IPv6 DNS validation support.
- Changed `wifi_connect` to accept open networks without requiring a password argument.
- Added per-command minimum and maximum argument bounds.

## Apps Manager

- Restricted user `.desktop` uninstall to known launcher directories.
- Blocked arbitrary file removal from apps marked as `source=user`.
- Added timeouts to Flatpak uninstall, Pacman uninstall, Flatpak override, and desktop-index refresh.
- Made desktop shortcut creation atomic.
- Preserved protected app and Steam-game uninstall behavior.

## Weather Backend

- Added stale-cache fallback when geocoding fails because of network errors.
- Added timeout protection to the Rust weather daemon when spawning `weather.py`.
- Added timeout protection to Rust-side notification dispatch.
- Rebuilt and installed live `weather-cli`.
- Rebuilt and installed live `astrea-weatherd`.

## Launch Backend

- Removed default latency socket fallback under world-writable `/tmp`.
- Added safer fallback under runtime/state paths.
- Prevented `launchd` from removing an active socket owned by another running daemon.
- Added stale socket detection before binding.
- Rebuilt and installed live `astrea-launch`.

## Music Bars Backend

- Removed Unix socket fallback under `/tmp`.
- Added safe runtime/state fallback path.
- Set socket permissions to `0600`.
- Added active-socket detection before stale socket removal.
- Added timeout protection around `pactl` probing.
- Rebuilt and installed live `music_bars_backend`.

## Tests Added Or Updated

- `Core/bridge/system/test_user_profile.py`
- `System/portal/test_filechooser_portal.py`
- `Apps/MediaViewer/tests/test_media_viewer_helper.py`
- `Core/bridge/system/test_storage_auto_refresh.py`
- `Core/bridge/wallpaper/test_wallpaper_manager.py`
- `Quickshell/desktop/test_app_index.py`
- `Core/bridge/network/test_manager.py`
- `Core/bridge/apps/test_manager.py`
- `Apps/Weather/backend/weather-core/src/lib.rs`
- `System/launch/src/lib.rs`

## Verification Run

- Ran focused Python backend tests.
- Ran `python3 -m py_compile` for modified Python backends.
- Ran `cargo fmt`.
- Ran `cargo test` for Weather backend.
- Ran `cargo test` for Launch backend.
- Ran `cargo test --features ipc-socket,ipc-stdout` for music-bars.
- Ran `cargo build --release` for Weather, Launch, and music-bars.
- Installed rebuilt binaries into the live runtime.
- Compared release binaries against installed live binaries with `cmp`.
- Smoke-tested `bin/weather-cli settings`.
- Smoke-tested `bin/astrea-launch history`.
- Smoke-tested `Core/bridge/audio/music_bars_backend`.
- Removed the temporary music-bars socket created by the smoke test.

## Installed Runtime Artifacts

- `bin/weather-cli`
- `bin/astrea-weatherd`
- `bin/astrea-launch`
- `Core/bridge/audio/music_bars_backend`
- `/usr/local/libexec/astrea-user-profile-helper`

## 2026-05-30 Weather Location And Notifications Update

### Weather App UI

- Added a location field to the Weather settings sheet.
- The app now saves the selected city through `weather-cli settings --city`.
- Applying a city triggers a forced refresh so the visible forecast changes immediately.
- The city input accepts plain city names and city/country forms such as `Paris, France` or `Springfield, United States`.
- The notifications row now uses a generic `Weather alerts` label outside Brazil and keeps `INMET alerts` for Brazilian locations.
- Alert cards now display the alert provider from the payload instead of hardcoding `INMET`.

### Weather Backend

- Added country-hint parsing for location queries.
- Improved geocode ranking so country hints such as `United States`, `France`, `BR`, or `US` are respected.
- Increased geocoding candidate count to improve disambiguation.
- Added alert-provider routing by country.
- INMET alerts are now fetched only when the resolved location has `country_code == "BR"`.
- Non-Brazilian locations now return an empty weather-provider alert list instead of calling the INMET API.
- Weather payloads now include `alert_sources` metadata for future country-specific alert providers.

### Weather CLI And Daemon

- Added flag-based settings support:
  - `weather-cli settings --notifications true|false`
  - `weather-cli settings --city "City, Country"`
- Preserved legacy positional settings calls for compatibility.
- Rebuilt and installed `bin/weather-cli`.
- Rebuilt and installed `bin/astrea-weatherd`.

### Notification Improvements

- Rust alert evaluation now keeps provider-specific alert kinds.
- INMET alerts keep the existing `inmet` kind.
- Future providers use `provider:<source>` style kinds, for example `provider:noaa`.
- Existing severe-weather derived notifications remain country-independent.

### Additional Tests And Verification

- Added `Core/bridge/apps/test_weather.py`.
- Added Rust tests for provider-specific alert kinds.
- Added Rust CLI test for flag-based settings updates.
- Ran `python3 Core/bridge/apps/test_weather.py`.
- Ran `python3 -m py_compile Core/bridge/apps/weather.py`.
- Ran `cargo fmt`.
- Ran `cargo test` for the Weather backend workspace.
- Ran `qmllint` for:
  - `Apps/Weather/ui/WeatherAppView.qml`
  - `Apps/Weather/ui/state/WeatherState.qml`
  - `Apps/Weather/ui/components/sections/WeatherAlerts.qml`
- Smoke-loaded the Weather QML entrypoint with `timeout 4s qs -p`.
- Smoke-tested flag-based CLI settings with a temporary settings file.
- Compared rebuilt Weather binaries against installed live binaries with `cmp`.

## 2026-05-30 Weather Loading And Automatic Location Fix

### Loading Fix

- Fixed the Weather CLI deadlock that could keep the app in an infinite loading state.
- Root cause: the Rust timeout helper waited for `weather.py` to exit before draining `stdout`; after the Weather JSON grew, the Python process could block on a full pipe.
- The Rust helper now captures and drains `stdout` and `stderr` while the backend process is still running.
- Added a regression test with large backend output so this pipe deadlock does not return.

### Automatic Location

- Changed empty Weather city settings to mean automatic location instead of defaulting to `Itajaí`.
- Added IP-based location resolution for empty city selections.
- Added two IP location providers with cached results:
  - `ipapi.co`
  - `ipwho.is`
- Kept `Itajaí` only as a final backend fallback if automatic IP location is unavailable.
- Added `--clear-city` support to `weather-cli settings`.
- Updated the Weather settings sheet so an empty city can be saved and shows `Automatic by IP`.
- The daemon now honors an empty saved city and lets the backend resolve the location automatically.

### Cache And Offline Behavior

- Added cache directory writability detection to `weather.py`.
- If `~/.cache/weather` is not writable, Weather falls back to `~/.local/state/Astrea/weather/cache`, then to `/tmp/astrea-weather-<uid>`.
- Added Rust stale-current fallback when the Python backend fails or times out, so Weather can still open with cached data instead of staying in loading.
- Marked stale fallback payloads with `stale: true` and a `stale_reason`.

### Additional Tests And Verification

- Added Python tests for automatic IP location and cache-directory fallback.
- Added Rust tests for large-output process draining and clearing the saved city.
- Ran `python3 Core/bridge/apps/test_weather.py`.
- Ran `python3 -m py_compile Core/bridge/apps/weather.py Core/bridge/apps/test_weather.py`.
- Ran `cargo fmt`.
- Ran `cargo test` for the Weather backend workspace.
- Ran `cargo build --release` for Weather backend binaries.
- Reinstalled `bin/weather-cli` and `bin/astrea-weatherd`.
- Compared rebuilt Weather binaries against installed live binaries with `cmp`.
- Confirmed `timeout 8s bin/weather-cli summary` now returns instead of hanging.
- Confirmed empty-city settings can be saved through `weather-cli settings --clear-city`.
- Verified the no-city path attempts automatic location; in the sandbox, external DNS failed, so the live-current stale fallback was used where available.

## 2026-05-30 Region Settings And System Geolocation

### Shared Region Preferences

- Added `Core/bridge/system/region.py` as the shared backend for language, country/region, time-format, and automatic-location preferences.
- Extended the existing Astrea system settings contract under `~/.config/AstreaOS/system/settings.json`.
- Added country/region defaults for Brazil, United States, Portugal, United Kingdom, France, Spain, Germany, Italy, Canada, Japan, Argentina, Chile, and Uruguay.
- Added time-format support:
  - `system`
  - `24h`
  - `12h`
- Added tests for regional defaults and automatic-location service control.

### Settings UI

- Reworked `Apps/Settings/pages/system/Language.qml` into a combined Language and Region page.
- Added a Country or region selector.
- Added a Time format selector.
- Added an Automatic location toggle.
- When Automatic location is disabled, Settings saves the preference and asks the backend to disable the GeoClue service.
- If GeoClue is not installed or not available in the current environment, the setting still saves and reports the service as unavailable instead of failing the page.

### Weather Location Flow

- Changed empty Weather city resolution to try system location first through GeoClue.
- IP location is now a fallback after system location fails.
- If automatic location is disabled, Weather no longer attempts GeoClue or IP lookup for an empty city.
- Weather keeps stale-cache fallback behavior so the app can still open when location/network services are unavailable.
- Added reverse geocoding for GeoClue coordinates so the payload can include city, state, country, and country code when available.
- Added regional time formatting to Weather payloads so hourly, sunrise, and sunset times can use 24-hour or AM/PM formatting.
- Updated Weather UI placeholder text from `Automatic by IP` to `Automatic location`.
- Updated sunrise/sunset UI parsing so AM/PM times do not break the next sun event calculation.

### Additional Tests And Verification

- Added `Core/bridge/system/test_region.py`.
- Updated `Core/bridge/apps/test_weather.py` for GeoClue-before-IP, disabled automatic location, and 12-hour formatting.
- Ran `python3 Core/bridge/system/test_region.py`.
- Ran `python3 Core/bridge/apps/test_weather.py`.
- Ran `python3 -m py_compile` for the Weather and Region backends.
- Ran `qmllint` for the updated Settings and Weather QML files.
- Smoke-loaded Settings with `timeout 4s qs -p /home/agony/.local/share/Astrea-Rolling/Apps/Settings/main.qml`.
- Smoke-loaded Weather with `timeout 4s qs -p /home/agony/.local/share/Astrea-Rolling/Apps/Weather/WeatherApp.qml`.
- Smoke-tested `region.py set --automatic-location false`; the sandbox reported GeoClue as unavailable because system bus access is blocked, but the preference save path completed.
- Smoke-tested Weather with automatic location disabled and an empty Weather city; it avoided live automatic lookup and returned stale cached data instead of loading indefinitely.

## 2026-05-30 Region Translation And Topbar Clock Sync

### Region Backend

- Added `effective_time_format` to `Core/bridge/system/region.py` responses.
- `system` time format now resolves to the selected country default in the shared Region backend.
- Added backend tests for Brazil/United States regional defaults and explicit 12-hour/24-hour overrides.

### Topbar Clock

- Updated the Quickshell topbar clock to read Astrea region settings.
- The clock now follows the Settings time-format selector:
  - `24h` shows `HH:MM`.
  - `12h` shows `HH:MM AM/PM`.
  - `system` follows the selected country default.
- Added live settings watching and a low-frequency backend refresh so topbar changes propagate after Settings saves.

### Lockscreen Clock

- Updated `Features/Paper/lockscreen/Lockscreen.qml` to read the same Astrea region settings as the topbar.
- The lockscreen clock now follows 24-hour, 12-hour, and country-default `system` modes.
- Added live region-settings watching so the lockscreen can update if the setting changes while it is open.
- Replaced hardcoded Portuguese lockscreen date/password/unlock fallbacks with i18n keys.

### Translation Polish

- Expanded English and Portuguese translations for the combined Language and Region page.
- Added translated country names for all currently supported region choices.
- Added long weekday and month translations for lockscreen date rendering.
- Updated the Settings sidebar label to `Language & Region` / `Idioma e Região`.
- Updated the time-format description to mention the topbar clock.
- The `System default` time-format option now shows the resolved country default, for example `System default (24-hour)`.

### Additional Tests And Verification

- Ran `python3 Core/bridge/system/test_region.py`.
- Ran `python3 Core/bridge/apps/test_weather.py`.
- Ran `python3 -m py_compile Core/bridge/apps/weather.py Core/bridge/system/region.py`.
- Validated `System/i18n/en_US.json` and `System/i18n/pt_BR.json` with `python3 -m json.tool`.
- Ran `qmllint` for:
  - `Apps/Settings/pages/system/Language.qml`
  - `Quickshell/bar/ui/components/system/base/Clock.qml`
  - `Features/Paper/lockscreen/Lockscreen.qml`
  - `Features/Paper/lockscreen/lockscreen.qml`
  - `Features/Paper/app/lockscreen/lockscreen.qml`
  - `System/i18n/I18n.qml`
  - `Apps/Settings/AstreaI18n/I18n.qml`
- Smoke-loaded Settings with `timeout 4s qs -p /home/agony/.local/share/Astrea-Rolling/Apps/Settings/main.qml`; it reached `Configuration Loaded`.
- Did not smoke-open the lockscreen because it captures the screen and keyboard by design.

## 2026-05-30 Control Center Polish

### Visual Polish

- Removed the compact top header from the Control Center after visual feedback, so the popup opens directly on the controls again.
- Kept the existing floating edit control outside the main card.
- Improved module card contrast with theme-driven `Theme.surface`, `Theme.shellHover`, `Theme.border`, and `Theme.accent` colors.
- Added pressed/hover feedback to tiles, connectivity rows, media buttons, and widget-library add/remove controls.
- Gave sliders a clearer icon capsule, theme-driven hover border, and better muted-state styling.
- Limited the module viewport height so the popup scrolls instead of growing too tall when extra controls are added.

### Translation And Theme Consistency

- Replaced hardcoded Portuguese/English status text in Control Center QML with i18n keys.
- Added Control Center translations for:
  - edit/done actions
  - active/inactive/on/off/searching/changing statuses
  - muted, Bluetooth, network, and media states
  - media fallback labels
  - module labels for display, sound, focus, mirror, Bluetooth, and AirDrop
- Cleaned the Control Center registry labels/summaries so fallback metadata is no longer Portuguese-only.
- Updated the widget library and edit-mode overlays to use theme tokens instead of hardcoded white/black colors.

### Additional Tests And Verification

- Ran `qmllint` for the updated Control Center popup, modules, widget library, and reorder stack.
- Validated `System/i18n/en_US.json` and `System/i18n/pt_BR.json` with `python3 -m json.tool`.
- Smoke-loaded the Quickshell entrypoint with `timeout 4s qs -p /home/agony/.local/share/Astrea-Rolling/Quickshell/shell.qml`; it reached `Configuration Loaded`.
