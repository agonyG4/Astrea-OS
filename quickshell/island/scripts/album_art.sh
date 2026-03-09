#!/bin/bash
URL=$(playerctl metadata mpris:artUrl 2>/dev/null)

if [[ $URL == https://* ]]; then
    CACHE="$HOME/.cache/island_art.jpg"
    curl -sL "$URL" -o "$CACHE"
    echo "$CACHE"
elif [[ $URL == file://* ]]; then
    echo "${URL/file:\/\//}"
else
    echo ""
fi
