#!/bin/bash
set -u

CAVA_CONF="$(dirname "$0")/../config/cava.conf"
MONITOR_SOURCE=""

source_exists() {
    local source_name="$1"
    [ -n "$source_name" ] || return 1
    pactl list short sources 2>/dev/null | awk '{print $2}' | grep -Fxq "$source_name"
}

default_monitor_source() {
    local default_sink
    default_sink="$(pactl get-default-sink 2>/dev/null || true)"
    if [ -n "$default_sink" ] && source_exists "${default_sink}.monitor"; then
        printf '%s.monitor\n' "$default_sink"
        return 0
    fi

    pactl list short sources 2>/dev/null | awk '$2 ~ /\.monitor$/ && $5 == "RUNNING" { print $2; exit }'
}

spotify_monitor_source() {
    local sink_name

    sink_name="$(pw-dump 2>/dev/null | jq -r '
        def is_spotify_client:
            [
                (.["application.name"] // ""),
                (.["application.process.binary"] // ""),
                (.["application.process.name"] // ""),
                (.["node.name"] // ""),
                (.["node.description"] // ""),
                (.["media.name"] // "")
            ]
            | map(ascii_downcase | contains("spotify"))
            | any;

        [.[] | select(.type == "PipeWire:Interface:Client") | .info.props | select(is_spotify_client) | .["object.id"]] as $spotify_clients
        | ([.[] | select(.type == "PipeWire:Interface:Node")
            | select(.info.props["media.class"] == "Stream/Output/Audio")
            | select((.info.props["client.id"] // -1) as $client_id | $spotify_clients | index($client_id))
        ] | first) as $spotify_node
        | if $spotify_node == null then
            empty
          else
            ($spotify_node.info.props["target.object"] // empty) as $target
            | if ($target | type) == "string" and $target != "" then
                $target
              else
                ($spotify_node.info.props["node.driver-id"] // empty) as $driver
                | if $driver == empty then
                    empty
                  else
                    ([.[] | select(.type == "PipeWire:Interface:Node")
                      | select(.id == (($driver | tostring) | tonumber))
                      | .info.props["node.name"]
                    ] | first) // empty
                  end
              end
          end' 2>/dev/null | head -1)"

    if [ -n "$sink_name" ] && source_exists "${sink_name}.monitor"; then
        printf '%s.monitor\n' "$sink_name"
    fi
}

for i in {1..15}; do
    MONITOR_SOURCE="$(spotify_monitor_source)"
    [ -n "$MONITOR_SOURCE" ] && break
    sleep 0.3
done

if [ -z "$MONITOR_SOURCE" ]; then
    MONITOR_SOURCE="$(default_monitor_source)"
fi

if [ -z "$MONITOR_SOURCE" ]; then
cat > "$CAVA_CONF" << EOF
[general]
bars = 6
framerate = 60
sensitivity = 100
[input]
method = pulse
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
EOF
    echo "ok:"
    exit 0
fi

cat > "$CAVA_CONF" << EOF
[general]
bars = 6
framerate = 60
sensitivity = 100
[input]
method = pulse
source = $MONITOR_SOURCE
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
EOF

echo "ok:$MONITOR_SOURCE"
