# Core Bridge

Shared backend and bridge helpers live here.

## Layout

- `apps/`: shared app-management helpers and Explorer backend integration.
- `audio/`: shared audio helpers and the music-bars backend.
- `network/`: NetworkManager bridge helpers.
- `system/`: system settings helpers such as audio, display, storage, and user profile.
- `wallpaper/`: wallpaper library, cache, and lockscreen helpers.
- `astrea_shared.py`: shared runtime path and desktop-entry utilities.
- `state_json.py`: safe JSON state read/write helper.

Compatibility scripts such as `apps.py`, `audio.py`, `display.py`,
`network.py`, `storage.py`, and `system.py` remain at the root because existing
launchers and QML processes call them directly.
