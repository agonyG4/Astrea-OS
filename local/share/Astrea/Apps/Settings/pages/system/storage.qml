import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"

Item {
    id: root

    readonly property string _script: Quickshell.env("HOME") + "/GitHub/Bench/StorageSense/sense.py"

    property bool   loading:          true
    property string _statsBuf:        ""
    property var    storageData:      []
    property real   totalSize:        0
    property real   diskTotal:        0
    property real   categorizedTotal: 0

    function formatBytes(bytes) {
        if (bytes < 1024)          return bytes.toFixed(0)  + " B"
        if (bytes < 1048576)       return (bytes / 1024).toFixed(1)       + " KB"
        if (bytes < 1073741824)    return (bytes / 1048576).toFixed(1)    + " MB"
        if (bytes < 1099511627776) return (bytes / 1073741824).toFixed(1) + " GB"
        return (bytes / 1099511627776).toFixed(1) + " TB"
    }

    // ── Processes ─────────────────────────────────────────────────────────

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
                        let s = 0
                        for (let i = 0; i < d.data.length; i++) s += d.data[i].size
                        root.categorizedTotal = s
                    }
                } catch (e) {
                    console.log("Error parsing storage JSON: " + e)
                }
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

    Component.onCompleted: { statsProc.running = true }

    // ── Loading indicator ─────────────────────────────────────────────────

    Item {
        anchors.centerIn: parent
        visible: root.loading
        width: 48; height: 48
        BusyIndicator { anchors.fill: parent; running: true }
    }

    // ── Main content ──────────────────────────────────────────────────────

    // ── Main content ──────────────────────────────────────────────────────
    ScrollPage {
        id: view
        visible: !root.loading
        maxWidth: 1000 // A bit wider for storage details
        
        SectionHeader { text: "ARMAZENAMENTO DO DISCO"; Layout.bottomMargin: 14 }
        
        Rectangle {
            Layout.fillWidth:    true
            Layout.bottomMargin: 32
            radius: 12
            color:  Theme.cardBg
            border { width: 1; color: Theme.cardBorder }
            implicitHeight: 120

            ColumnLayout {
                anchors { fill: parent; margins: 20 }
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Capacidade Utilizada"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.totalSize > 0 ? (root.formatBytes(root.totalSize) + " de " + root.formatBytes(root.diskTotal) + " usados") : "Calculando..."
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 20
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border { width: 1; color: Theme.cardBorder }
                    clip: true

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: root.storageData
                            Rectangle {
                                height: parent.height
                                width: root.categorizedTotal > 0 ? (modelData.size / root.categorizedTotal) * parent.width : 0
                                color: modelData.color
                                border.width: width > 1 ? 1 : 0
                                border.color: Qt.rgba(0, 0, 0, 0.15)
                            }
                        }
                    }
                }
            }
        }

        SectionHeader { text: "ARMAZENAMENTO DA HOME"; Layout.bottomMargin: 14 }
        
        Rectangle {
            Layout.fillWidth:    true
            Layout.bottomMargin: 28
            radius: 12
            color:  Theme.cardBg
            border { width: 1; color: Theme.cardBorder }
            implicitHeight: homeCatCol.implicitHeight

            ColumnLayout {
                id: homeCatCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                Repeater {
                    model: root.storageData.filter(d => !d.is_system)
                    
                    SettingRow {
                        required property var  modelData
                        required property int  index
                        label:    modelData.label
                        sublabel: root.formatBytes(modelData.size)
                        textPrimary:   Theme.textPrimary
                        textSecondary: Theme.textSecondary
                        cardBorder:    Theme.cardBorder
                        isLast: index === root.storageData.filter(d => !d.is_system).length - 1
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: modelData.color
                        }
                    }
                }
            }
        }

        SectionHeader { text: "ARMAZENAMENTO DO SISTEMA"; Layout.bottomMargin: 14 }
        
        Rectangle {
            Layout.fillWidth:    true
            Layout.bottomMargin: 32
            radius: 12
            color:  Theme.cardBg
            border { width: 1; color: Theme.cardBorder }
            implicitHeight: sysCatCol.implicitHeight

            ColumnLayout {
                id: sysCatCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                Repeater {
                    model: root.storageData.filter(d => d.is_system)
                    
                    SettingRow {
                        required property var  modelData
                        required property int  index
                        label:    modelData.label
                        sublabel: root.formatBytes(modelData.size)
                        textPrimary:   Theme.textPrimary
                        textSecondary: Theme.textSecondary
                        cardBorder:    Theme.cardBorder
                        isLast: index === root.storageData.filter(d => d.is_system).length - 1
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: modelData.color
                        }
                    }
                }
            }
        }
    }
}
