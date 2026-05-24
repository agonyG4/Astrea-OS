# Astrea - Polkit Auth

Related notes: [[Astrea - System Layer]], [[Astrea - I18n]], [[Astrea - Design Rules]]

## Folder
`System/auth/`

## Files
- `System/auth/astrea-polkit-agent.py`
- `System/auth/astrea-polkit-agent.qml`
- `System/auth/astrea-polkit-prompt.py`
- `System/auth/astrea-polkit-agent.service`
- `System/auth/auth_helper`
- `System/auth/auth_helper.c`
- `System/auth/test_polkit_agent.py`

## Responsibility
Astrea owns two auth-related paths:
- a Polkit authentication agent for graphical privilege prompts
- a setuid `auth_helper` used by lockscreen/auth-related paths

Treat this folder as a security boundary.

## Polkit Agent
`astrea-polkit-agent.py` registers a Polkit agent listener and starts prompt flows.

It can call:
- `astrea-polkit-prompt.py` for a GTK password prompt

`astrea-polkit-agent.qml` is the Quickshell Polkit prompt implementation using `Quickshell.Services.Polkit`.

The QML prompt reads:
- `~/.config/AstreaOS/ui/theme.json`
- `System/i18n/i18n.py dump`

## Install
The service installer path is:
- `System/services/install-polkit-agent.sh`

The service file is:
- `System/services/astrea-polkit-agent.service`

## Rules
- Do not log passwords or prompt responses.
- Do not widen `auth_helper` behavior without tests and explicit review.
- Keep prompt copy in [[Astrea - I18n]] when it is user-facing.
- Validate both Python syntax and the available graphical prompt path.

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/System/auth/astrea-polkit-agent.py`
- `python3 -m py_compile /home/agony/.local/share/Astrea/System/auth/astrea-polkit-prompt.py`
- `python3 /home/agony/.local/share/Astrea/System/auth/astrea-polkit-prompt.py --self-test`
- `python3 /home/agony/.local/share/Astrea/System/auth/test_polkit_agent.py`
