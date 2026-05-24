# Astrea - Session Daemon

Related notes: [[Astrea - Core Bridge]], [[Astrea - System Layer]], [[Astrea - State JSON Bridge]]

## File
`Core/bridge/astrea_sessiond.py`

## Responsibility
`astrea_sessiond.py` is a lightweight session daemon scaffold.

It currently exposes:
- a status heartbeat
- a simple health domain
- a foreground `run` loop

## Commands
- `status`
- `state [domain]`
- `run --interval <seconds>`

Current domain:
- `health`

## State
Status is written to:
- `~/.local/state/Astrea/sessiond-status.json`

Runtime socket path is reported as:
- `$XDG_RUNTIME_DIR/Astrea/sessiond.sock`

If `XDG_RUNTIME_DIR` is missing, it falls back under:
- `~/.local/state/Astrea/runtime/Astrea/sessiond.sock`

## Current Limitation
The socket path is reported, but the inspected implementation is still a heartbeat/status scaffold rather than a full request-serving Unix socket daemon.

Do not document new session domains as active until `domain_state()` and consumers are updated.

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/Core/bridge/astrea_sessiond.py`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/astrea_sessiond.py status`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/astrea_sessiond.py state health`
