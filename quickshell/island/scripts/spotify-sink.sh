#!/bin/bash
CAVA_CONF="/home/agony/.config/quickshell/island/config/cava.conf"

SPOTIFY_SERIAL=""

# Espera um pouco pois o playerctl (mpris) pode reportar antes do pipewire criar a stream de audio
sleep 1

for i in {1..10}; do
    SPOTIFY_SERIAL=$(pw-dump 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for node in data:
    props = node.get('info', {}).get('props', {})
    media_class = props.get('media.class', '')
    node_name = props.get('node.name', '')
    app_name = props.get('application.name', '')
    if ('spotify' in node_name.lower() or 'spotify' in app_name.lower()) and media_class == 'Stream/Output/Audio':
        print(props.get('object.serial', ''))
        break
" 2>/dev/null)

    if [ -n "$SPOTIFY_SERIAL" ]; then
        break
    fi
    sleep 0.5
done

if [ -z "$SPOTIFY_SERIAL" ]; then
    # Evita fallback para 'auto' que captura todos os áudios do PC (bug reportado).
    # Em vez disso, tenta o nome do node direto.
    SOURCE_LINE="source = spotify"
else
    SOURCE_LINE="source = $SPOTIFY_SERIAL"
fi

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