#!/bin/bash
CAVA_CONF="$(dirname "$0")/../config/cava.conf"
SPOTIFY_SERIAL=""

for i in {1..15}; do
    SPOTIFY_SERIAL=$(pw-dump 2>/dev/null | jq -r '
        .[] | select(
            .info.props["media.class"] == "Stream/Output/Audio" and
            (
                (.info.props["node.name"] // "" | ascii_downcase | contains("spotify")) or
                (.info.props["application.name"] // "" | ascii_downcase | contains("spotify"))
            )
        ) | .info.props["object.serial"] // empty' 2>/dev/null | head -1)

    [ -n "$SPOTIFY_SERIAL" ] && break
    sleep 0.3
done

SOURCE_LINE="${SPOTIFY_SERIAL:+source = $SPOTIFY_SERIAL}"
SOURCE_LINE="${SOURCE_LINE:-source = spotify}"

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