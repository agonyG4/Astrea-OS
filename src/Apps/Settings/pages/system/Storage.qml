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
    property var    storageData:      []
    property real   totalSize:        0
    property real   diskTotal:        0
    property real   scannedTotal:     0
    property real   categorizedTotal: 0
    property bool   scanning:         false
    property string errorMessage:     ""
    property bool   autoScanStarted:  false

    readonly property var homeData:   storageData.filter(d => !d.is_system)
    readonly property var systemData: storageData.filter(d => d.is_system)

    function formatBytes(bytes) {
        if (bytes < 1000)          return bytes.toFixed(0)              + " B"
        if (bytes < 1000000)       return (bytes / 1000).toFixed(1)     + " KB"
        if (bytes < 1000000000)    return (bytes / 1000000).toFixed(1)  + " MB"
        if (bytes < 1000000000000) return (bytes / 1000000000).toFixed(1) + " GB"
        return (bytes / 1000000000000).toFixed(1) + " TB"
    }

    function usedPercent() {
        return diskTotal > 0 ? totalSize / diskTotal : 0
    }

    function compressionSavings() {
        return Math.max(0, scannedTotal - totalSize)
    }

    function usageText() {
        if (totalSize <= 0) {
            if (scanning)
                return "Escaneando armazenamento..."
            if (errorMessage !== "")
                return "Nenhum índice de armazenamento disponível"
            return "Calculando..."
        }

        let text = formatBytes(totalSize) + " de " + formatBytes(diskTotal) + " usados"
        const saved = compressionSavings()
        if (saved > 0)
            text += " · " + formatBytes(saved) + " comprimidos"
        return text
    }

    function startScan(showLoading) {
        if (scanProc.running)
            return
        if (showLoading === undefined)
            showLoading = true
        errorMessage = ""
        scanning = true
        if (showLoading)
            loading = true
        scanTimeout.restart()
        scanProc.running = true
    }

    // ── Processes ──────────────────────────────────────────────────────────

    Process {
        id: statsProc
        command: ["python3", root._script, "json"]
        running: false
        stdout: StdioCollector { id: statsStdout }
        onExited: (code) => {
            root.errorMessage = ""
            if (code === 0 && statsStdout.text !== "") {
                try {
                    const d = JSON.parse(statsStdout.text)
                    if (d.error)
                        root.errorMessage = d.error
                    if (d.disk_used)  root.totalSize = d.disk_used
                    if (d.disk_total) root.diskTotal  = d.disk_total
                    if (d.scanned_total) root.scannedTotal = d.scanned_total
                    if (d.data) {
                        root.storageData = d.data
                        root.categorizedTotal = d.data.reduce((s, i) => s + i.size, 0)
                    }
                    if (d.error === "No cache found" && !root.autoScanStarted) {
                        root.autoScanStarted = true
                        root.startScan(true)
                        return
                    }
                    if (!d.error && d.cache_updated_ago_seconds > 86400 && root.storageData.length > 0 && !root.autoScanStarted) {
                        root.autoScanStarted = true
                        root.startScan(false)
                    }
                } catch (e) {
                    root.errorMessage = "Could not parse storage data"
                    console.log("Storage JSON error: " + e)
                }
            } else {
                root.errorMessage = "Could not load storage data"
            }
            root.loading = false
        }
    }

    Process {
        id: scanProc
        command: ["python3", root._script, "scan", "--quiet"]
        running: false
        onExited: function(exitCode) {
            scanTimeout.stop()
            root.scanning = false
            if (exitCode !== 0) {
                root.loading = false
                root.errorMessage = root.storageData.length > 0 ? "" : "Could not scan storage"
                return
            }
            root.loading = true
            statsProc.running = false
            statsProc.running = true
        }
    }

    Timer {
        id: scanTimeout
        interval: 120000
        repeat: false
        onTriggered: {
            if (scanProc.running)
                scanProc.running = false
            root.scanning = false
            root.loading = false
            root.errorMessage = "Storage scan timed out"
        }
    }

    Component.onCompleted: {
        statsProc.running = true
    }

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
                            text: root.usageText()
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
