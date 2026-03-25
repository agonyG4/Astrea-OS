import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ApplicationWindow {
    id: window
    visible: true
    width: 375
    height: 475
    minimumWidth: 375
    minimumHeight: 475
    maximumWidth: 375
    maximumHeight: 475
    title: "About"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    onClosing: (close) => {
        Qt.exit(0)
    }

    property string sysKernel:  "..."
    property string sysDesktop: "..."
    property string sysCpu:     "..."
    property string sysGpu:     "..."
    property string sysMemory:  "..."
    property string sysStorage: "..."
    property string sysOs:      "..."
    property string sysName:    "..."
    property string sysVersion: "..."

    Process {
        command: ["bash", "-c", "source /etc/os-release && echo $PRETTY_NAME"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysOs = line.trim() }
    }

    Process {
        command: ["bash", "-c", "source /etc/os-release && echo $V_NAME"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysName = line.trim() }
    }

    Process {
        command: ["bash", "-c", "source /etc/os-release && echo ${VERSION:-$VERSION_ID}"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysVersion = line.trim() }
    }

    Process {
        command: ["uname", "-r"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysKernel = line.trim() }
    }

    Process {
        command: ["bash", "-c", "hyprctl version 2>/dev/null | grep -oP 'v[\\d.]+' | head -1"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var v = line.trim()
                window.sysDesktop = v !== "" ? "Hyprland " + v : "Hyprland"
            }
        }
    }

    Process {
        command: ["bash", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //;s/(R)//g;s/(TM)//g;s/ CPU//g;s/  */ /g'"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysCpu = line.trim() }
    }

    Process {
        command: ["bash", "-c", "lspci | grep -i 'vga\\|3d\\|display' | grep -iv 'intel' | grep -oP '(?<=\\[).*(?=\\])' | sed 's/ Lite Hash Rate//gi;s/ Little Hash Rate//gi;s/ LHR//gi;s/ (LHR)//gi' | head -1"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysGpu = line.trim() }
    }

    Process {
        command: ["bash", "-c", "awk '/MemTotal/{gb=($2/1024/1024); printf \"%.0f GB\", (gb>15&&gb<16)?16:gb}' /proc/meminfo"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysMemory = line.trim() }
    }

    Process {
        command: ["bash", "-c", "df -h / | awk 'NR==2{print $3\" used of \"$2}'"]
        running: true
        stdout: SplitParser { onRead: (line) => window.sysStorage = line.trim() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 36
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: window.sysOs
            color: "#f5f5f7"
            font.pixelSize: 26
            font.weight: Font.Light
            font.family: "Inter, Helvetica Neue, sans-serif"
            horizontalAlignment: Text.AlignHCenter
        }

        Item { height: 4 }

        Text {
            Layout.fillWidth: true
            text: window.sysName
            color: "#636366"
            font.pixelSize: 13
            font.family: "Inter, Helvetica Neue, sans-serif"
            horizontalAlignment: Text.AlignHCenter
        }

        Item { height: 2 }

        Text {
            Layout.fillWidth: true
            text: window.sysVersion
            color: "#636366"
            font.pixelSize: 13
            font.family: "Inter, Helvetica Neue, sans-serif"
            horizontalAlignment: Text.AlignHCenter
        }

        Item { height: 28 }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#2c2c2e"
        }

        Item { height: 24 }

        Item {
            Layout.fillWidth: true
            height: specGrid.implicitHeight

            GridLayout {
                id: specGrid
                anchors.horizontalCenter: parent.horizontalCenter
                width: 280
                columns: 2
                rowSpacing: 16
                columnSpacing: 0

                SpecLabel { label: "Kernel" }
                SpecValue { value: window.sysKernel }

                SpecLabel { label: "Desktop" }
                SpecValue { value: window.sysDesktop }

                SpecLabel { label: "Processor" }
                SpecValue { value: window.sysCpu }

                SpecLabel { label: "Graphics" }
                SpecValue { value: window.sysGpu }

                SpecLabel { label: "Memory" }
                SpecValue { value: window.sysMemory }

                SpecLabel { label: "Storage" }
                SpecValue { value: window.sysStorage }
            }
        }

        Item { Layout.fillHeight: true }
    }

    component SpecLabel: Text {
        Layout.preferredWidth: 100
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
        color: "#636366"
        font.pixelSize: 13
        font.family: "Inter, Helvetica Neue, sans-serif"
        required property string label
        text: label
    }

    component SpecValue: Text {
        Layout.preferredWidth: 160
        Layout.maximumWidth: 160
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.leftMargin: 16
        color: "#e0e0e5"
        font.pixelSize: 13
        font.family: "Inter, Helvetica Neue, sans-serif"
        wrapMode: Text.WordWrap
        required property string value
        text: value
    }
}