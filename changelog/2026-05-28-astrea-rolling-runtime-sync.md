# Astrea Rolling Runtime Sync

Date: 2026-05-28
Branch: runtime sync branch
Source of truth: local Astrea rolling runtime
Target repo: AstreaOS repository

## Summary

Syncs the current live Astrea Rolling runtime into `Astrea-Dev/src`, updates Spatial Audio to the packaged 7.1 HRIR asset, and refreshes the agent docs used by future code agents.

This is a broad runtime refresh. The most important user-facing fix in this change is the Spatial Audio contract:

- active sink: `effect_input.virtual-surround-7.1-astrea`
- legacy fallback sink: `effect_input.virtual-surround-7.1-hesuvi`
- canonical HRIR asset: `src/audio/hrir.wav`
- HRIR format: `48000 Hz`, `16 channels`, `0.050s`
- generated PipeWire HRIR path: `${ASTREA_ROOT:-$HOME/.local/share/Astrea}/audio/hrir.wav`

## What Changed

### Spatial Audio

- Replaced `src/audio/hrir.wav` with the new 7.1 / 16-channel HRIR.
- Added `src/audio/astrea_sidefix_7p1_16ch_50ms_safe_-10dB.wav` as an explicit provenance copy.
- Added `src/System/config/pipewire/astrea-audio-engine.conf` as the repo-side template for the generated PipeWire spatial chain.
- Updated `src/Core/bridge/system/audio.py` to detect the loaded Astrea spatial sink while keeping fallback support for the old HeSuVi sink name.
- Updated `src/Apps/Settings/pages/connectivity/Audio.qml` to use the backend-reported spatial sink with `effect_input.virtual-surround-7.1-astrea` only as a fallback.
- Moved the active PipeWire config away from machine-local paths and onto a generated config that resolves the packaged Astrea runtime HRIR asset and current physical target sink at runtime.

### Runtime Sync

- Refreshed `src` from the current live Rolling runtime.
- Excluded cache, build output, tmp files, runtime `Data`, `Backups`, and `Wallpapers` from the sync.
- Brought over current live changes across Settings, Explorer, Weather, Core bridges, shared controls, Quickshell, Island, notifications, desktop icons, system scripts, and status services.
- Removed `src/Apps/Explorer/state/JsonWorker.js` because it is no longer present in the live runtime.

### Shell And UI Runtime

- Synced current Quickshell updates for bar, tray, control center, volume popup/OSD, network and Bluetooth popups, workspace UI, notifications, spotlight, desktop icons, Alt-Tab, and Island.
- Added modular Island runtime files for geometry, interaction, state, mode hosting, game mode, idle mode, and music mode.
- Added current Quickshell component settings and service manager runtime files.

### Core Components And Theme

- Synced shared controls such as `Button`, `ButtonCapsule`, `DualButton`, and `FloatingButton`.
- Added `Core/components/AppIcon.qml` plus Core/component README updates.
- Added the Borealis theme module under `Core/components/theme/Borealis`.
- Updated theme integration used by app and shell surfaces.

### Bridges, Services, And Tests

- Updated app-manager bridge behavior and tests.
- Updated network/system bridge tests.
- Updated `astrea_statusd.py` and its tests.
- Updated Polkit/auth runtime files from the live tree.
- Updated gaming settings, volume OSD, and theme decoration scripts.

### Agent Docs

- Updated `agent/Astrea/AGENTS.md` and `agent/Astrea/AGENT_START_HERE.md` with routing for audio, PipeWire, HRIR, spatial output, and sink-routing tasks.
- Updated `agent/Astrea/05 Bridges/Astrea - Audio Bridge.md` with the new spatial sink and HRIR contract.
- Updated `agent/Astrea/07 Data/Astrea - Assets and Data.md` to document `audio/hrir.wav` as the canonical 7.1 HRIR asset.
- Updated `agent/Astrea/03 Apps/Astrea - Settings App.md` with the Settings Audio page contract.
- Mirrored the same agent docs into the local user-facing docs mirror.

## Key Files

Audio and Settings:

- `src/audio/hrir.wav`
- `src/audio/astrea_sidefix_7p1_16ch_50ms_safe_-10dB.wav`
- `src/System/config/pipewire/astrea-audio-engine.conf` (template rendered by `audio.py generate-spatial-config`)
- `src/Core/bridge/system/audio.py`
- `src/Apps/Settings/pages/connectivity/Audio.qml`

Agent documentation:

- `agent/Astrea/AGENTS.md`
- `agent/Astrea/AGENT_START_HERE.md`
- `agent/Astrea/03 Apps/Astrea - Settings App.md`
- `agent/Astrea/05 Bridges/Astrea - Audio Bridge.md`
- `agent/Astrea/07 Data/Astrea - Assets and Data.md`

Broad runtime areas:

- `src/Apps/Explorer`
- `src/Apps/Settings`
- `src/Apps/Weather`
- `src/Core`
- `src/Features/Files`
- `src/Quickshell`
- `src/System`

## Validation

- [x] Verified runtime HRIR format with `ffprobe`.
- [x] Verified repo HRIR format with `ffprobe`.
- [x] Confirmed both HRIR copies report `48000|16|0.050000`.
- [x] Ran `python3 -m py_compile` on `src/Core/bridge/system/audio.py`.
- [x] Ran `qmllint` on `src/Apps/Settings/pages/connectivity/Audio.qml`.
- [x] Ran `git diff --check`.
- [x] Verified `agent/Astrea` and the local docs mirror match with `diff -qr`.
- [x] Reloaded PipeWire and confirmed the live default sink is `effect_input.virtual-surround-7.1-astrea`.
- [x] Checked recent PipeWire journal output; no missing-WAV/path error appeared after reload.

Validation commands used:

```bash
ffprobe -v error -show_entries stream=sample_rate,channels,duration -of compact=p=0:nk=1 "$ASTREA_ROOT/audio/hrir.wav"
ffprobe -v error -show_entries stream=sample_rate,channels,duration -of compact=p=0:nk=1 src/audio/hrir.wav
python3 -m py_compile src/Core/bridge/system/audio.py
qmllint src/Apps/Settings/pages/connectivity/Audio.qml
git diff --check
diff -qr agent/Astrea "$ASTREA_DOCS_MIRROR"
```

## Review Notes

- This is intentionally a broad runtime sync, not a narrow one-file patch.
- The sync excludes generated/cache/build/user-data areas, but reviewers should still scan new runtime directories before merge.
- Spatial Audio now depends on the packaged Astrea runtime HRIR path rather than a machine-local WAV path.
- Backups were created locally before the sync:
  - `.codex/backups/src-before-spatial-sync-20260528`
  - local docs mirror backup for the spatial-agent sync

## Suggested PR Title

```text
Sync Astrea Rolling runtime and spatial audio HRIR
```
