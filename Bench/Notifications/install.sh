#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
service_dir="${XDG_DATA_HOME:-"$HOME/.local/share"}/dbus-1/services"
service_file="$service_dir/org.freedesktop.Notifications.service"

mkdir -p "$service_dir"
chmod +x "$project_dir/notification_daemon.py"

cat > "$service_file" <<SERVICE
[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=$project_dir/notification_daemon.py
SERVICE

echo "Installed $service_file"
echo "Test with: notify-send 'Bench Notifications' 'DBus activation is working.'"
