#!/bin/bash
art=$(playerctl metadata mpris:artUrl 2>/dev/null)

[[ -z "$art" ]] && exit 1

if [[ "$art" == http* ]]; then
    curl -s "$art" -o /tmp/waybar_cover.jpg
else
    cp "${art/file:\/\//}" /tmp/waybar_cover.jpg
fi

echo "/tmp/waybar_cover.jpg"