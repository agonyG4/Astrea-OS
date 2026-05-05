import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"

Item {
    id: root

    readonly property string _script: Quickshell.env("HOME") + "/.local/share/Astrea/Core/bridge/system/storage.py"

    property bool   loading:          true
    property string _statsBuf:        ""
    property var    storageData:      []
    property real   totalSize:        0
    property real   diskTotal:        0
    property real   categorizedTotal: 0

    readonly property var homeData:   storageData.filter(d => !d.is_system)
    readonly property var systemData: storageData.filter(d => d.is_system)

    function formatBytes(bytes) {
        if (bytes < 1024)          return bytes.toFixed(0)        + " B"
        if (bytes < 1048576)       return (bytes / 1024).toFixed(1)       + " KB"
        if (bytes < 1073741824)    return (bytes / 1048576).toFixed(1)    + " MB"
        if (bytes < 1099511627776) return (bytes / 1073741824).toFixed(1) + " GB"
        return (bytes / 1099511627776).toFixed(1) + " TB"
    }

    function usedPercent() {
        return diskTotal > 0 ? totalSize / diskTotal : 0
    }

    // ── Processes ──────────────────────────────────────────────────────────

    Process {
        id: statsProc
        command: ["python3", root._script, "json"]
        running: false
        stdout: SplitParser { onRead: (l) => root._statsBuf += l }
        onExited: (code) => {
            root.loading = false
            if (code === 0 && root._statsBuf !== "") {
                try {
                    const d = JSON.parse(root._statsBuf)
                    if (d.disk_used)  root.totalSize = d.disk_used
                    if (d.disk_total) root.diskTotal  = d.disk_total
                    if (d.data) {
                        root.storageData = d.data
                        root.categorizedTotal = d.data.reduce((s, i) => s + i.size, 0)
                    }
                } catch (e) { console.log("Storage JSON error: " + e) }
            }
            root._statsBuf = ""
        }
    }

    Process {
        id: scanProc
        command: ["python3", root._script, "scan", "--quiet"]
        running: false
        onExited: { statsProc.running = true }
    }

    Component.onCompleted: statsProc.running = true

    // ── Loading ────────────────────────────────────────────────────────────

    Item {
        anchors.centerIn: parent
        visible: root.loading
        width: 48; height: 48
        BusyIndicator { anchors.fill: parent; running: true }
    }

    // ── Main content ───────────────────────────────────────────────────────

    ScrollPage {
        visible: !root.loading
        maxWidth: 960

        // ── Disk Overview Card ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.04)
            implicitHeight: overviewCol.implicitHeight + 48

            ColumnLayout {
                id: overviewCol
                anchors { fill: parent; margins: 24 }
                spacing: 16

                // Title + usage text
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Armazenamento"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            renderType: Text.NativeRendering
                        }
                        Text {
                            text: root.totalSize > 0
                                ? root.formatBytes(root.totalSize) + " de " + root.formatBytes(root.diskTotal) + " usados"
                                : "Calculando…"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.letterSpacing: 0
                            renderType: Text.NativeRendering
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Percent badge
                    Rectangle {
                        implicitWidth:  pctLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: 980
                        color: {
                            const p = root.usedPercent()
                            if (p > 0.9) return Qt.rgba(1, 0.23, 0.19, 0.18)
                            if (p > 0.7) return Qt.rgba(1, 0.62, 0, 0.15)
                            return Qt.rgba(10/255, 132/255, 1, 0.15)
                        }
                        Text {
                            id: pctLabel
                            anchors.centerIn: parent
                            text: root.diskTotal > 0
                                ? Math.round(root.usedPercent() * 100) + "% usado"
                                : "—"
                            color: {
                                const p = root.usedPercent()
                                if (p > 0.9) return "#ff3b30"
                                if (p > 0.7) return "#ff9f0a"
                                return Theme.accent
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.letterSpacing: 0
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Progress bar — segmented
                Item {
                    Layout.fillWidth: true
                    height: 8

                    // Track
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Segments via Canvas para respeitar radius nas pontas
                    Row {
                        anchors.fill: parent
                        spacing: 1
                        clip: false

                        Repeater {
                            id: barRepeater
                            model: root.storageData

                            Item {
                                height: parent.height
                                width: root.categorizedTotal > 0
                                    ? Math.max(0, (modelData.size / root.categorizedTotal) * (barRepeater.parent.width - (root.storageData.length - 1)))
                                    : 0

                                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                                // segmento com radius só nas pontas corretas
                                Rectangle {
                                    anchors.fill: parent
                                    color: modelData.color
                                    // pontas esquerdas arredondadas só no primeiro
                                    topLeftRadius:    index === 0 ? 4 : 0
                                    bottomLeftRadius: index === 0 ? 4 : 0
                                    // pontas direitas arredondadas só no último
                                    topRightRadius:    index === root.storageData.length - 1 ? 4 : 0
                                    bottomRightRadius: index === root.storageData.length - 1 ? 4 : 0
                                }
                            }
                        }
                    }
                }

                // Legend dots
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    Repeater {
                        model: root.storageData
                        Row {
                            spacing: 5
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData.color
                            }
                            Text {
                                text: modelData.label
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.letterSpacing: 0
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }

        // Spacer
        Item { Layout.fillWidth: true; implicitHeight: 24 }

        // ── Home ──────────────────────────────────────────────────────────
        SectionHeader { text: "HOME"; Layout.bottomMargin: 10 }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 12
            color: Theme.cardBg
            border { width: 1; color: Theme.cardBorder }
            implicitHeight: homeCol.implicitHeight

            ColumnLayout {
                id: homeCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0
                Repeater {
                    model: root.homeData
                    delegate: StorageRow { isLast: index === root.homeData.length - 1 }
                }
            }
        }

        // ── System ────────────────────────────────────────────────────────
        SectionHeader { text: "SISTEMA"; Layout.bottomMargin: 10 }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 32
            radius: 12
            color: Theme.cardBg
            border { width: 1; color: Theme.cardBorder }
            implicitHeight: sysCol.implicitHeight

            ColumnLayout {
                id: sysCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0
                Repeater {
                    model: root.systemData
                    delegate: StorageRow { isLast: index === root.systemData.length - 1 }
                }
            }
        }
    }

    // ── Delegate ───────────────────────────────────────────────────────────
    component StorageRow: SettingRow {
        required property var  modelData
        required property int  index
        required property bool isLast

        label:         modelData.label
        sublabel:      root.formatBytes(modelData.size)
        textPrimary:   Theme.textPrimary
        textSecondary: Theme.textSecondary
        cardBorder:    Theme.cardBorder

        // Mini bar
        RowLayout {
            spacing: 10
            implicitWidth: 140

            Rectangle {
                implicitWidth: 80; implicitHeight: 4; radius: 2
                color: Qt.rgba(1, 1, 1, 0.08)
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: modelData.color
                    width: root.categorizedTotal > 0
                        ? Math.max(2, (modelData.size / root.categorizedTotal) * 80)
                        : 0
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                width: 8; height: 8; radius: 4
                color: modelData.color
            }
        }
    }
}
