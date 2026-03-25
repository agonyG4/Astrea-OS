#!/bin/bash
source "${HOME}/.local/share/Astrea/Settings/components/visual/monitor-settings.conf"

vrr=${vrr:-0}

cat > ~/.config/hypr/conf/monitors.conf << EOF
monitor=$monitor,${resolution}@${refreshrate},0x0,${scale},bitdepth,$bitdepth,vrr,$vrr
EOF

hyprctl reload