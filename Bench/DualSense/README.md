# DualSense Bench

Small Quickshell/QML control panel for `dualsensectl`.

## Run

```sh
qs -p /home/agony/GitHub/Bench/DualSense/gamepad.qml
```

## Features

- Device refresh, battery and firmware info.
- Lightbar color, brightness and on/off state.
- Player LEDs and LED brightness.
- Microphone, microphone LED, microphone mode, speaker route and volume.
- Rumble/trigger attenuation.
- Adaptive trigger modes: off, feedback, weapon, bow, galloping, machine and vibration.
- Bluetooth power-off action.

## Structure

- `gamepad.qml`: main entry file.
- `GamepadWindow.qml`: window composition.
- `backend/DualSenseBackend.qml`: QML process bridge and app state.
- `ui/panels/`: feature panels for adaptive triggers, lightbar, LEDs, microphone/audio and attenuation.
- `ui/controls/`: local UI primitives used by the panels.
- `scripts/dualsense_manager.py`: JSON wrapper around `dualsensectl`.
- `AstreaComponents`: symlink to `~/.local/share/Astrea/Core/components`, used by the UI for shared theme/form controls.
