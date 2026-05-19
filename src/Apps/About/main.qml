import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "AstreaI18n" as AstreaI18n

ApplicationWindow {
    id: window
    visible: true
    width: 640
    height: 420
    minimumWidth: 640
    minimumHeight: 420
    maximumWidth: 640
    maximumHeight: 420
    title: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.title"]) || "About AstreaOS"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    onClosing: (close) => { Qt.exit(0) }

    // ── System Info ──────────────────────────────────────────────
    property string sysKernel:  "..."
    property string sysDesktop: "..."
    property string sysCpu:     "..."
    property string sysGpu:     "..."
    property string sysMemory:  "..."
    property string sysStorage: "..."
    property string sysOs:      "AstreaOS"
    property string sysName:    "..."
    property string sysVersion: "..."
    property string _infoBuf:   ""
    readonly property string infoScript: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/system/info.py"

    Process {
        id: infoProc
        command: ["python3", window.infoScript]
        running: true
        stdout: SplitParser {
            onRead: data => window._infoBuf += data
        }
        onExited: code => {
            if (code !== 0) {
                window._infoBuf = ""
                return
            }
            try {
                var payload = JSON.parse(window._infoBuf || "{}")
                var system = payload.system || {}
                var hardware = payload.hardware || {}
                window.sysOs = system.distro || "AstreaOS"
                window.sysName = system.distro_codename || ""
                window.sysVersion = system.distro_version || ""
                window.sysKernel = system.kernel || "Unknown"
                window.sysDesktop = system.desktop_label || system.desktop || "Unknown"
                window.sysCpu = hardware.cpu || "Unknown"
                window.sysGpu = hardware.gpu || "Unknown"
                window.sysMemory = hardware.memory_total || "Unknown"
                window.sysStorage = system.storage_root || "Unknown"
            } catch (e) {
                console.log("About system info parse failed:", e)
            }
            window._infoBuf = ""
        }
    }

    // ── Root card ────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: "#1c1c1e"

        // Subtle inner top highlight
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.45
            radius: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1,1,1,0.04) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Drag area (window move)
        MouseArea {
            property point pressPos
            anchors.fill: parent
            onPressed: (mouse) => { pressPos = Qt.point(mouse.x, mouse.y) }
            onPositionChanged: (mouse) => {
                if (pressed)
                    window.setX(window.x + mouse.x - pressPos.x)
                    window.setY(window.y + mouse.y - pressPos.y)
            }
        }

        // Close button
        Rectangle {
            anchors { top: parent.top; left: parent.left; margins: 16 }
            width: 13; height: 13; radius: 6.5
            color: closeDot.containsMouse ? "#ff5f57" : "#3a3a3c"
            border.color: closeDot.containsMouse ? "#c6352a" : "transparent"
            border.width: 0.5
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "×"
                color: "#4a0000"
                font { pixelSize: 9; weight: Font.Bold }
                visible: closeDot.containsMouse
            }

            MouseArea {
                id: closeDot
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.exit(0)
            }
        }

        // ── Two-column layout ────────────────────────────────────
        Row {
            anchors {
                fill: parent
                margins: 0
            }

            // LEFT — logo + name + version
            Item {
                width: 220
                height: parent.height

                // Big "A" logo zone
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(1,1,1,0.015)
                    radius: 14
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    // OS Logo (large letter mark)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "A"
                        color: "#f2f2f7"
                        font { pixelSize: 96; weight: Font.Light; letterSpacing: -4 }
                    }

                    Item { height: 8 }

                    // OS Name
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: window.sysOs
                        color: "#f2f2f7"
                        font { pixelSize: 17; weight: Font.DemiBold; letterSpacing: -0.3 }
                    }

                    Item { height: 4 }

                    // Version
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.version"]) || "Version {version}").replace("{version}", window.sysVersion)
                        color: "#636366"
                        font { pixelSize: 12 }
                    }

                    Item { height: 2 }

                    // Codename
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: window.sysName !== "..." ? window.sysName : ""
                        color: "#48484a"
                        font { pixelSize: 11; italic: true }
                        visible: window.sysName !== "..." && window.sysName !== ""
                    }

                    Item { height: 20 }

                    // "Software Atualizado" pill
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 156; height: 28; radius: 8
                        color: softBtn.containsMouse ? "#2c2c2e" : "#252527"
                        border.color: "#3a3a3c"; border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 7; height: 7; radius: 3.5
                                color: "#30d158"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.software_updated"]) || "Software up to date"
                                color: "#8e8e93"
                                font { pixelSize: 11 }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: softBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }

            // Vertical divider
            Rectangle {
                width: 1
                height: parent.height - 48
                anchors.verticalCenter: parent.verticalCenter
                color: "#2c2c2c"
            }

            // RIGHT — specs list
            Item {
                width: parent.width - 220 - 1
                height: parent.height

                Column {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left; leftMargin: 28
                        right: parent.right; rightMargin: 24
                    }
                    spacing: 0

                    Repeater {
                        model: [
                            { label: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.label.kernel"]) || "Kernel",       value: window.sysKernel  },
                            { label: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.label.desktop"]) || "Desktop",     value: window.sysDesktop },
                            { label: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.label.processor"]) || "Processor", value: window.sysCpu     },
                            { label: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.label.gpu"]) || "GPU",             value: window.sysGpu     },
                            { label: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.label.memory"]) || "Memory",       value: window.sysMemory  },
                            { label: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["about.label.storage"]) || "Storage",     value: window.sysStorage },
                        ]

                        delegate: Item {
                            width: parent ? parent.width : 380
                            height: 52

                            // Row separator (only between items, not last)
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 1
                                color: "#252527"
                                visible: index < 5
                            }

                            Row {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 0

                                // Label
                                Text {
                                    text: modelData.label
                                    color: "#636366"
                                    font { pixelSize: 12 }
                                    width: 90
                                }

                                // Value
                                Text {
                                    text: modelData.value
                                    color: "#e5e5ea"
                                    font { pixelSize: 12 }
                                    width: parent.width - 90
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
