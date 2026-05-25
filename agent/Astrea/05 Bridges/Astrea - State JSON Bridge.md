# Astrea - State JSON Bridge

Related notes: [[Astrea - Core Bridge]], [[Astrea - Data Flow]], [[Astrea - Assets and Data]]

## File
`Core/bridge/state_json.py`

## Responsibility
Small JSON state helper for QML and bridge code.

It provides atomic reads/writes without creating a full domain-specific backend.

## Commands
- `read <path>`
- `write <path> <payload>`
- `write <path> --stdin`
- `read-or-init <path> <default_payload> [legacy_path]`

`write` validates JSON before writing. Writes use `astrea_shared.atomic_write_text`, so callers get a same-directory temp file and atomic replace.

## Migration Use
`read-or-init` can seed a new state file from:
- an existing target file
- a legacy path
- a validated default payload

Use this for small state files only. If behavior needs commands, side effects, or nontrivial validation, create or extend a domain bridge instead.

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/Core/bridge/state_json.py`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/state_json.py read ~/.local/state/Astrea/example.json`
- `printf '{}' | python3 /home/agony/.local/share/Astrea/Core/bridge/state_json.py write ~/.local/state/Astrea/example.json --stdin`
