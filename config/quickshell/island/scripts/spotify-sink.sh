#!/bin/bash
CAVA_CONF="$(dirname "$0")/../config/cava.conf"
SPOTIFY_SERIAL=""

for i in {1..15}; do
    SPOTIFY_SERIAL=$(pw-dump 2>/dev/null | jq -r '
        .[]
        | select(.info.props["media.class"] == "Stream/Output/Audio")
        | .info.props as $p
        | select(
            [
                ($p["application.name"] // ""),
                ($p["application.process.binary"] // ""),
                ($p["application.process.name"] // ""),
                ($p["node.name"] // ""),
                ($p["node.description"] // ""),
                ($p["media.name"] // "")
            ]
            | map(ascii_downcase | contains("spotify"))
            | any
        )
        | ($p["object.serial"] // empty)' 2>/dev/null | head -1)

    [ -n "$SPOTIFY_SERIAL" ] && break
    sleep 0.3
done

SOURCE_LINE=""
[ -n "$SPOTIFY_SERIAL" ] && SOURCE_LINE="source = $SPOTIFY_SERIAL"

cat > "$CAVA_CONF" << EOF
[general]
bars = 6
framerate = 60
sensitivity = 100
[input]
method = pipewire
$SOURCE_LINE
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
EOF

echo "ok:$SPOTIFY_SERIAL"
