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
            IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -Po '(?<=dev )\\S+');
            if [ -z \"$IFACE\" ]; then
                echo 'none||0 B/s|0 B/s';
                exit 0;
            fi;
            if [ -d \"/sys/class/net/$IFACE/wireless\" ]; then
                TYPE='wifi';
                SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -n1);
            else
                TYPE='wired';
                SSID='Ethernet';
            fi;
            echo \"$TYPE|$SSID|--|--\"
        "]
        running: false
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
