import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool   connected: false
    property string type:      "none"
    property string ssid:      ""
    property string download:  "0 B/s"
    property string upload:    "0 B/s"

    function refresh() {
        netProc.running = false
        netProc.running = true
    }

    property var netProc: Process {
        command: ["bash", "-c", "
            RX_PREV=-1; TX_PREV=-1;
            while true; do
                IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -Po '(?<=dev )\\S+');
                if [ -z \"$IFACE\" ]; then
                    echo 'none||0 B/s|0 B/s';
                    sleep 1;
                    continue;
                fi;
                if [ -d \"/sys/class/net/$IFACE/wireless\" ]; then
                    TYPE='wifi';
                    SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -n1);
                else
                    TYPE='wired';
                    SSID='Ethernet';
                fi;
                RX=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0);
                TX=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0);
                if [ \"$RX_PREV\" != -1 ]; then
                    awk -v type=\"$TYPE\" -v ssid=\"$SSID\" -v rx=$(($RX - $RX_PREV)) -v tx=$(($TX - $TX_PREV)) 'BEGIN {
                        printf \"%s|%s|%.1f %s|%.1f %s\\n\", type, ssid,
                            rx>=1048576?rx/1048576:(rx>=1024?rx/1024:rx), rx>=1048576?\"MB/s\":(rx>=1024?\"KB/s\":\"B/s\"),
                            tx>=1048576?tx/1048576:(tx>=1024?tx/1024:tx), tx>=1048576?\"MB/s\":(tx>=1024?\"KB/s\":\"B/s\")
                    }';
                fi;
                RX_PREV=$RX; TX_PREV=$TX;
                sleep 1;
            done
        "]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.split('|');
                if (p.length >= 4) {
                    root.type = p[0];
                    root.ssid = p[1];
                    root.download = p[2];
                    root.upload = p[3];
                    root.connected = (root.type !== "none");
                }
            }
        }
    }
}
