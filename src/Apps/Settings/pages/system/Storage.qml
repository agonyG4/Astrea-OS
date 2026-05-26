import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

Item {
    id: root

    readonly property string _script: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/system/storage.py"
    property bool   loading:          true
    property var    storageData:      []
    property real   totalSize:        0
    property real   diskTotal:        0
    property real   scannedTotal:     0
    property real   compressionAmount: 0
    property real   compressionSaved: 0
    property real   zstdDiskUsage: 0
    property bool   compressionExact: false
    property bool   compressionStale: false
    property real   categorizedTotal: 0
    property bool   scanning:         false
    property bool   refreshRunning:   false
    property bool   cacheStale:       false
    property int    refreshPollSecs:  5
    property string errorMessage:     ""
    property bool   autoScanStarted:  false

    readonly property var homeData:   storageData.filter(d => !d.is_system)
    readonly property var systemData: storageData.filter(d => d.is_system)

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    function isPacman(item) {
        return item && item.id === "sys:pacman"
    }

    function formatBytes(bytes) {
        bytes = Math.max(0, bytes || 0)
        if (bytes < 1024) return bytes.toFixed(0) + " B"

        const units = ["KiB", "MiB", "GiB", "TiB", "PiB"]
        let value = bytes / 1024
        let index = 0
        while (value >= 1024 && index < units.length - 1) {
            value /= 1024
            index += 1
        }
        return value.toFixed(index >= 2 ? 2 : 1) + " " + units[index]
    }

    function usedPercent() {
        return diskTotal > 0 ? totalSize / diskTotal : 0
    }

    function compressionDisplayAmount() {
        if (compressionExact && zstdDiskUsage > 0)
            return zstdDiskUsage
        return Math.max(0, compressionAmount > 0 ? compressionAmount : compressionSaved)
    }

    function usageText() {
        if (totalSize <= 0) {
            if (scanning)
                return t("apps.settings.pages.system.storage.status.scanning_storage", "Scanning storage...")
            if (errorMessage !== "")
                return t("apps.settings.pages.system.storage.status.no_storage_index", "No storage index available")
            return t("apps.settings.pages.system.storage.status.calculating", "Calculating...")
        }

        let text = t("apps.settings.pages.system.storage.status.used_of_total", "{used} of {total} used", {
            used: formatBytes(totalSize),
            total: formatBytes(diskTotal)
        })
        const compressed = compressionDisplayAmount()
        if (compressed > 0)
            text += " · " + (compressionExact && zstdDiskUsage > 0 && !compressionStale ? "" : "~") + t("apps.settings.pages.system.storage.status.compressed", "{amount} compressed", {
                amount: formatBytes(compressed)
            })
        if (refreshRunning)
            text += " · " + t("apps.settings.pages.system.storage.status.updating", "updating")
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
                    root.compressionAmount = d.compressed_total || d.compression_total || 0
                    root.compressionSaved = d.compressed_saved || d.compression_saved || 0
                    root.zstdDiskUsage = d.zstd_disk_usage || 0
                    root.compressionExact = d.compressed_exact === true
                    root.compressionStale = d.compressed_stale === true
                    root.refreshRunning = d.refresh_running === true
                    root.scanning = root.refreshRunning
                    root.cacheStale = d.cache_stale === true
                    root.refreshPollSecs = Math.max(2, d.refresh_poll_seconds || 5)
                    if (d.data) {
                        root.storageData = d.data
                        root.categorizedTotal = d.data.reduce((s, i) => s + i.size, 0)
                    }
                    if (root.refreshRunning && !refreshPollTimer.running) {
                        refreshPollTimer.interval = root.refreshPollSecs * 1000
                        refreshPollTimer.start()
                    } else if (!root.refreshRunning) {
                        refreshPollTimer.stop()
                    }
                } catch (e) {
                    root.errorMessage = root.t("apps.settings.pages.system.storage.error.parse", "Could not parse storage data")
                    console.log("Storage JSON error: " + e)
                }
            } else {
                root.errorMessage = root.t("apps.settings.pages.system.storage.error.load", "Could not load storage data")
            }
            root.loading = root.refreshRunning && root.storageData.length === 0
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
                root.errorMessage = root.storageData.length > 0 ? "" : root.t("apps.settings.pages.system.storage.error.scan", "Could not scan storage")
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
            root.errorMessage = root.t("apps.settings.pages.system.storage.error.scan_timeout", "Storage scan timed out")
        }
    }

    Timer {
        id: refreshPollTimer
        interval: 5000
        repeat: true
        onTriggered: {
            if (!statsProc.running)
                statsProc.running = true
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
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.storage.text.armazenamento"]) || "Storage")
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
                            return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                        }
                        Text {
                            id: pctLabel
                            anchors.centerIn: parent
                            text: root.diskTotal > 0
                                ? root.t("apps.settings.pages.system.storage.status.percent_used", "{percent}% used", {
                                    percent: Math.round(root.usedPercent() * 100)
                                })
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
                            PacmanIcon {
                                width: 8; height: 8
                                visible: root.isPacman(modelData)
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData.color
                            }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                visible: !root.isPacman(modelData)
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

        // ── User ──────────────────────────────────────────────────────────
        SectionHeader { text: root.t("apps.settings.pages.system.storage.text.home", "HOME"); Layout.bottomMargin: 10 }

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
        SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.storage.text.sistema"]) || "SYSTEM"); Layout.bottomMargin: 10 }

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
                visible: !root.isPacman(modelData)
                color: modelData.color
            }

            PacmanIcon {
                width: 10; height: 10
                visible: root.isPacman(modelData)
                color: modelData.color
            }
        }
    }

    component PacmanIcon: Canvas {
        id: icon
        property color color: "#FFD426"
        onColorChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            const r = Math.min(w, h) / 2
            const cx = w / 2
            const cy = h / 2
            ctx.clearRect(0, 0, w, h)
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.arc(cx, cy, r, Math.PI * 0.18, Math.PI * 1.82, false)
            ctx.closePath()
            ctx.fillStyle = color
            ctx.fill()
        }
    }
}
