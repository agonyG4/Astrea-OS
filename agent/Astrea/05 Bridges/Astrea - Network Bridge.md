# Astrea - Network Bridge

Related notes: [[Astrea - Core Bridge]], [[Astrea - Settings App]], [[Astrea - System Layer]], [[Astrea - External Dependencies]]

## File
`Core/bridge/network/manager.py`

Compatibility entrypoint:
- `Core/bridge/network.py`

## Responsibility
Network backend for the Settings Internet page.

It provides:
- interface RX/TX counters
- active connection and DNS state
- DNS preset/custom DNS apply
- Wi-Fi radio status, scan results, connect, and disconnect
- Cloudflare WARP install/status/service/tray state
- WARP connect, disconnect, and restart actions when `warp-cli` is installed

## Consumer
`Apps/Settings/pages/connectivity/Internet.qml`

## Commands
- `stats`
- `dns_info`
- `set_dns <connection> <auto|servers>`
- `wifi_status`
- `wifi_connect <ssid> [password]`
- `wifi_disconnect`
- `wifi_set_enabled on|off`
- `warp_status`
- `warp_set_enabled on|off`
- `warp_restart`

All commands print JSON.

## Dependencies
- NetworkManager / `nmcli`
- `ip`
- `systemctl`
- optional `warp-cli`
- optional `warp-svc.service`
- optional user `warp-taskbar.service`

## DNS Contract
The Internet page presents presets for Auto, Cloudflare, Google, Quad9, and AdGuard.

`set_dns` validates IP addresses and applies either automatic DNS or a whitespace-separated server list through NetworkManager.

## Wi-Fi Contract
Wi-Fi payloads include:
- availability
- enabled state
- device name
- adapter state
- connected SSID
- networks with SSID, signal, security, active state, and password requirement

Network rows should use the bridge payload instead of parsing `nmcli` directly in QML.

## WARP Contract
WARP is optional. When `warp-cli` is missing, the bridge returns an installed=false payload instead of treating that as a fatal Settings error.

Actions may need privileged systemd control. The bridge tries regular systemctl, then `pkexec`, then non-interactive `sudo` where available.

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/Core/bridge/network/manager.py`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/network/manager.py stats`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/network/manager.py dns_info`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/network/manager.py wifi_status`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/network/manager.py warp_status`
