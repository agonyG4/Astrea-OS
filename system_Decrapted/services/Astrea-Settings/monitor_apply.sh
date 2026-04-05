#!/bin/bash
source /etc/Astrea-Settings/monitor-settings.conf

cat > ~/.config/hypr/conf/monitors.conf << EOF
monitor=$MONITOR_NAME,${MONITOR_RES}@${MONITOR_HZ},0x0,1,bitdepth,$BIT_DEPTH
EOF

hyprctl reload