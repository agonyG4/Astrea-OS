import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

Item {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color accent:        Theme.accent
    readonly property color textPrimary:   Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg:        Theme.cardBg
    readonly property color cardBorder:    Theme.cardBorder
    readonly property color errorColor:    Theme.errorColor

    // ── Paths ─────────────────────────────────────────────────────────────
    readonly property string home:        Quickshell.env("HOME")
    readonly property string scriptPath:  home + "/.local/share/Astrea/Core/bridge/system/display.py"
    readonly property string confPath:    home + "/.local/share/Astrea/System/config/display/monitor-settings.conf"
    readonly property string applyScript: home + "/.local/share/Astrea/System/services/display_apply.sh"
    readonly property string nightShiftScript: home + "/.local/share/Astrea/System/services/display_night_shift_color.sh"
    readonly property string wallpaperThumbPath: home + "/.config/AstreaOS/user/paper/wallpaper/wallpaper_thumb.jpg"
    readonly property string wallpaperPreviewSource: "file://" + wallpaperThumbPath + "?t=" + Date.now()

    // ── Monitor state ─────────────────────────────────────────────────────
    property var    monitors:      []
    property int    activeMonitor: 0
    property string errorMessage:  ""
    property bool   loading:       true

    readonly property var mon: activeMonitor >= 0 && activeMonitor < monitors.length ? monitors[activeMonitor] : null

    // ── Settings state ────────────────────────────────────────────────────
    property int  selectedResolution: 0
    property int  selectedHz:         0
    property int  selectedBitdepth:   1
    property int  selectedScale:      2
    property int  selectedVrrMode:    0
    property int  selectedSaturation: 93
    property bool nightShiftEnabled:  false
    property int  nightShiftStrength: 35
    property bool nightShiftScheduleEnabled: false
    property string nightShiftStart: "20:00"
    property string nightShiftEnd: "07:00"
    property bool showAllResolutions: false
    property bool savedVisible:       false
    property bool suppressLiveColorApply: true
    property string pendingLiveApplyMode: ""
    property bool previewReady: false

    onSelectedResolutionChanged: selectedHz = 0
    onSelectedSaturationChanged: queueLiveColorApply("saturation-only")
    onNightShiftEnabledChanged: queueLiveColorApply("night-shift-only")
    onNightShiftScheduleEnabledChanged: if (!suppressLiveColorApply) persistSettingsOnly(false)
    onNightShiftStartChanged: if (!suppressLiveColorApply) persistSettingsOnly(false)
    onNightShiftEndChanged: if (!suppressLiveColorApply) persistSettingsOnly(false)

    // ── Computed ──────────────────────────────────────────────────────────
    readonly property var currentHzList:
        mon && mon.refreshRates && mon.resolutions && mon.resolutions.length > selectedResolution
            ? (mon.refreshRates[mon.resolutions[selectedResolution]] || [])
            : []

    readonly property var vrrModeOptions: [
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.off"]) || "Off"), value: 0 },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.on"]) || "On"), value: 1 },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.fullscreen_only"]) || "Fullscreen only"), value: 2 }
    ]
    readonly property var hourOptions: Array.from({ length: 24 }, (_, i) => String(i).padStart(2, "0"))
    readonly property var minuteOptions: ["00", "15", "30", "45"]

    readonly property var defaultResolutionIndices: {
        if (!mon || mon.resolutions.length === 0) return []
        const resols  = mon.resolutions
        const lastIdx = resols.length - 1
        const nativeH = parseInt(resols[lastIdx].split("x")[1])
        const indices = { [lastIdx]: true, [selectedResolution]: true }

        ;[720, 900, 1080, 1440, 2160]
            .filter(h => h < nativeH)
            .slice(-2)
            .forEach(h => {
                let best = -1
                resols.forEach((r, i) => {
                    const [w, rh] = r.split("x").map(Number)
                    if (rh === h && (best < 0 || w > Number(resols[best].split("x")[0])))
                        best = i
                })
                if (best >= 0) indices[best] = true
            })

        return Object.keys(indices).map(Number).sort((a, b) => b - a)
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function _idx(arr, val) { const i = arr.indexOf(val); return i >= 0 ? i : 0 }

    function _applyCurrentValues() {
        if (!mon) return
        suppressLiveColorApply = true
        const cur = mon.current
        selectedResolution = _idx(mon.resolutions, cur.resolution)
        const hzList = mon.refreshRates[cur.resolution] || []
        selectedHz         = Math.max(0, hzList.indexOf(cur.refreshRate))
        selectedBitdepth   = _idx(mon.bitdepths, cur.bitdepth)
        selectedScale      = _idx(mon.scales, cur.scale)
        selectedVrrMode    = _idx(vrrModeOptions.map(option => option.value), cur.vrrMode !== undefined ? cur.vrrMode : 0)
        selectedSaturation = cur.saturation !== undefined ? cur.saturation : 93
        nightShiftEnabled  = cur.nightShift !== undefined ? cur.nightShift : false
        nightShiftStrength = cur.nightShiftStrength !== undefined ? cur.nightShiftStrength : 35
        nightShiftScheduleEnabled = cur.nightShiftSchedule !== undefined ? cur.nightShiftSchedule : false
        nightShiftStart = cur.nightShiftStart !== undefined ? cur.nightShiftStart : "20:00"
        nightShiftEnd = cur.nightShiftEnd !== undefined ? cur.nightShiftEnd : "07:00"
        showAllResolutions = false
        suppressLiveColorApply = false
    }

    function _monitorLabel(m) {
        if (!m)
            return ""
        const model = ((m && m.model) ? m.model : "").trim()
        const make = ((m && m.make) ? m.make : "").trim()
        const shortName = model !== "" ? model : (make !== "" ? make : m.name)
        return m.name + " — " + shortName
    }

    function _monitorType(m) {
        const name = (m && m.name ? m.name : "").toLowerCase()
        const desc = (m && m.description ? m.description : "").toLowerCase()
        if (name.indexOf("edp") !== -1 || name.indexOf("lvds") !== -1 ||
            desc.indexOf("built-in") !== -1 || desc.indexOf("internal") !== -1)
            return "laptop"
        return "monitor"
    }

    function _screenAspectRatio(m) {
        const res = (m && m.current && m.current.resolution) ? m.current.resolution : ""
        const parts = res.split("x")
        if (parts.length !== 2)
            return 16 / 10
        const w = Math.max(1, parseInt(parts[0]))
        const h = Math.max(1, parseInt(parts[1]))
        return w / h
    }

    function _resolutionSize(resolution, rotated) {
        const parts = String(resolution || "").split("x")
        let w = parts.length === 2 ? Math.max(1, parseInt(parts[0])) : 1920
        let h = parts.length === 2 ? Math.max(1, parseInt(parts[1])) : 1080
        if (rotated) {
            const tmp = w
            w = h
            h = tmp
        }
        return { width: w, height: h }
    }

    function _monitorRotated(m) {
        const transform = m && m.geometry && m.geometry.transform !== undefined
            ? m.geometry.transform
            : (m && m.current && m.current.transform !== undefined ? m.current.transform : 0)
        return transform === 1 || transform === 3 || transform === 5 || transform === 7
    }

    function _previewSizeForMonitor(m, monitorIndex) {
        const selected = monitorIndex === activeMonitor
        const resolution = selected && mon
            ? mon.resolutions[selectedResolution]
            : (m && m.current && m.current.resolution ? m.current.resolution : "")
        return _resolutionSize(resolution, _monitorRotated(m))
    }

    function _monitorBounds() {
        if (!monitors || monitors.length === 0)
            return { minX: 0, minY: 0, maxX: 1920, maxY: 1080, width: 1920, height: 1080 }
        let minX = 999999
        let minY = 999999
        let maxX = -999999
        let maxY = -999999
        monitors.forEach((m, i) => {
            const size = _previewSizeForMonitor(m, i)
            const x = m && m.geometry && m.geometry.x !== undefined ? m.geometry.x : 0
            const y = m && m.geometry && m.geometry.y !== undefined ? m.geometry.y : 0
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x + size.width)
            maxY = Math.max(maxY, y + size.height)
        })
        const width = Math.max(1, maxX - minX)
        const height = Math.max(1, maxY - minY)
        return { minX: minX, minY: minY, maxX: maxX, maxY: maxY, width: width, height: height }
    }

    function _displayTitle(m) {
        if (!m)
            return ""
        if (_monitorType(m) === "laptop")
            return "Laptop Display"
        const model = ((m && m.model) ? m.model : "").trim()
        return model !== "" ? model : m.name
    }

    function _displaySubtitle(m) {
        if (!m)
            return ""
        const typeLabel = _monitorType(m) === "laptop" ? "Built-in display" : "External display"
        return typeLabel + " • " + m.name
    }

    function _currentRefreshLabel() {
        const hz = root.currentHzList[root.selectedHz]
        return hz ? hz + " Hz" : "—"
    }

    function _selectedResolutionLabel() {
        if (!mon || !mon.resolutions || selectedResolution < 0 || selectedResolution >= mon.resolutions.length)
            return mon && mon.current && mon.current.resolution ? mon.current.resolution : ""
        return mon.resolutions[selectedResolution]
    }

    function _currentVrrLabel() {
        const option = vrrModeOptions[selectedVrrMode]
        return option ? option.label : "Off"
    }

    function _timeHour(value) {
        const parts = String(value || "00:00").split(":")
        return parts.length > 0 ? parts[0].padStart(2, "0") : "00"
    }

    function _timeMinute(value) {
        const parts = String(value || "00:00").split(":")
        return parts.length > 1 ? parts[1].padStart(2, "0") : "00"
    }

    function _setTimeHour(propName, hour) {
        root[propName] = String(hour).padStart(2, "0") + ":" + _timeMinute(root[propName])
    }

    function _setTimeMinute(propName, minute) {
        root[propName] = _timeHour(root[propName]) + ":" + String(minute).padStart(2, "0")
    }

    function queueLiveColorApply(mode) {
        if (suppressLiveColorApply || !mon || loading || errorMessage !== "")
            return
        pendingLiveApplyMode = mode
        liveColorApplyTimer.restart()
    }

    function saturationPercentToNvibrant(value) {
        const percent = Math.max(0, Math.min(100, Math.round(value)))
        return Math.round(percent * 1023 / 100)
    }

    function persistSettingsOnly(showFeedback = false) {
        if (!mon) return
        saveSettings(showFeedback, "persist-only")
    }

    function saveSettings(showFeedback = true, applyMode = "full") {
        if (!mon) return
        const safe = s => String(s).replace(/'/g, "'\\''")
        const content = [
            "monitor="     + mon.name,
            "monitor_id="  + (mon.id !== undefined ? mon.id : 0),
            "resolution="  + mon.resolutions[selectedResolution],
            "refreshrate=" + (currentHzList[selectedHz] !== undefined ? currentHzList[selectedHz] : mon.current.refreshRate),
            "bitdepth="    + mon.bitdepths[selectedBitdepth],
            "scale="       + mon.scales[selectedScale],
            "vrr="         + (vrrModeOptions[selectedVrrMode] ? vrrModeOptions[selectedVrrMode].value : 0),
            "saturation="  + selectedSaturation,
            "night_shift=" + (nightShiftEnabled ? 1 : 0),
            "night_shift_strength=" + nightShiftStrength,
            "night_shift_schedule=" + (nightShiftScheduleEnabled ? 1 : 0),
            "night_shift_start=" + nightShiftStart,
            "night_shift_end=" + nightShiftEnd
        ].join("\n")
        saveProc.command = [
            "bash", "-c",
            `mkdir -p "$(dirname '${safe(confPath)}')" && ` +
            `printf '%s' '${safe(content)}' > '${safe(confPath)}'`
        ]
        saveProc.applyMode = applyMode
        saveProc.running = true
        if (showFeedback) {
            savedVisible = true
            savedTimer.restart()
        }
    }

    // ── Processos ─────────────────────────────────────────────────────────
    property string _stdoutBuf: ""

    Process {
        id: fetchProc
        command: ["python3", root.scriptPath]
        running: false
        stdout: SplitParser {
            onRead: (line) => root._stdoutBuf += line
        }
        onExited: (code, _) => {
            root.loading = false
            if (code !== 0 && root._stdoutBuf === "") {
                root.errorMessage = "Script failed (exit " + code + ")"
                return
            }
            try {
                const data = JSON.parse(root._stdoutBuf)
                if (data.error) { root.errorMessage = data.error; return }
                root.monitors      = data.monitors
                const ai           = data.monitors.findIndex(m => m.name === data.activeMonitor)
                root.activeMonitor = ai >= 0 ? ai : 0
                root._applyCurrentValues()
                root.previewReady = false
                previewReadyTimer.restart()
            } catch (e) {
                root.errorMessage = "JSON parse error: " + e
            }
        }
    }

    Process {
        id: saveProc
        running: false
        command: []
        property string applyMode: "full"
        onExited: (code, _) => {
            if (code === 0) {
                if (saveProc.applyMode !== "persist-only") {
                    applyProc.command = saveProc.applyMode === "full"
                        ? ["bash", root.applyScript]
                        : ["bash", root.applyScript, saveProc.applyMode]
                    applyProc.running = true
                }
            }
        }
    }

    Process {
        id: saturationProc
        command: []
        running: false
        onExited: (code, _) => {
            if (code !== 0)
                root.errorMessage = "nvibrant failed (exit " + code + ")"
        }
    }

    Process {
        id: nightShiftProc
        command: []
        running: false
        onExited: (code, _) => {
            if (code !== 0)
                root.errorMessage = "hyprsunset IPC failed (exit " + code + ")"
        }
    }

    Process {
        id: applyProc
        command: []
        running: false
        onExited: (code, _) => {
            if (code !== 0) root.errorMessage = "Apply failed (exit " + code + ")"
        }
    }

    Timer {
        id: savedTimer
        interval: 2000
        onTriggered: root.savedVisible = false
    }

    Timer {
        id: liveColorApplyTimer
        interval: 180
        repeat: false
        onTriggered: {
            const mode = root.pendingLiveApplyMode || "colors-only"
            root.pendingLiveApplyMode = ""
            if (mode === "saturation-only") {
                saturationProc.command = ["nvibrant", root.mon.name, String(root.saturationPercentToNvibrant(root.selectedSaturation))]
                saturationProc.running = false
                saturationProc.running = true
                root.persistSettingsOnly(false)
            } else if (mode === "night-shift-only") {
                nightShiftProc.command = [
                    root.nightShiftScript,
                    root.nightShiftEnabled && root.nightShiftStrength > 0 ? "on" : "off",
                    String(root.nightShiftStrength)
                ]
                nightShiftProc.running = false
                nightShiftProc.running = true
                root.persistSettingsOnly(false)
            } else {
                root.saveSettings(false, mode)
            }
        }
    }

    Component.onCompleted: fetchProc.running = true

    Timer {
        id: previewReadyTimer
        interval: 160
        repeat: false
        onTriggered: root.previewReady = true
    }

    component ValueSlider: Item {
        id: sliderRoot
        implicitWidth: 220
        implicitHeight: 28
        property real minValue: 0
        property real maxValue: 100
        property real stepSize: 1
        property real value: 0
        signal valueModified(real value)
        signal editingFinished(real value)

        function snappedValue(rawValue) {
            const clamped = Math.max(minValue, Math.min(maxValue, rawValue))
            const stepped = Math.round((clamped - minValue) / stepSize) * stepSize + minValue
            return Math.max(minValue, Math.min(maxValue, stepped))
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.10)

            Rectangle {
                width: ((sliderRoot.value - sliderRoot.minValue) / Math.max(1, sliderRoot.maxValue - sliderRoot.minValue)) * parent.width
                height: parent.height
                radius: 2
                color: root.accent
            }
        }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: ((sliderRoot.value - sliderRoot.minValue) / Math.max(1, sliderRoot.maxValue - sliderRoot.minValue)) * (sliderRoot.width - width)
            Behavior on x { enabled: !dragArea.pressed; NumberAnimation { duration: 80 } }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            enabled: sliderRoot.enabled
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            function updateValue(mouseX) {
                const ratio = Math.max(0, Math.min(1, mouseX / sliderRoot.width))
                sliderRoot.value = sliderRoot.snappedValue(sliderRoot.minValue + ratio * (sliderRoot.maxValue - sliderRoot.minValue))
                sliderRoot.valueModified(sliderRoot.value)
            }

            onPressed: (mouse) => updateValue(mouse.x)
            onPositionChanged: (mouse) => {
                if (pressed)
                    updateValue(mouse.x)
            }
            onReleased: sliderRoot.editingFinished(sliderRoot.value)
        }
    }

    component DisplayPreview: Item {
        id: preview
        implicitHeight: 252

        readonly property int resolutionVersion: root.selectedResolution
        readonly property var bounds: {
            resolutionVersion
            return root._monitorBounds()
        }
        readonly property real previewScale: Math.min(
            width / Math.max(1, bounds.width),
            height / Math.max(1, bounds.height)
        ) * 0.78

        Repeater {
            model: root.monitors

            delegate: Item {
                id: monitorItem
                readonly property var monitor: modelData
                readonly property var displaySize: {
                    preview.resolutionVersion
                    return root._previewSizeForMonitor(monitor, index)
                }
                readonly property bool active: index === root.activeMonitor
                readonly property bool laptop: root._monitorType(monitor) === "laptop"
                readonly property real screenW: Math.max(56, displaySize.width * preview.previewScale)
                readonly property real screenH: Math.max(36, displaySize.height * preview.previewScale)
                readonly property real chrome: laptop ? 12 : 10
                readonly property real footH: laptop ? 16 : 38

                width: screenW + chrome * 2
                height: screenH + chrome * 2 + footH
                x: (preview.width - preview.bounds.width * preview.previewScale) / 2
                    + (((monitor && monitor.geometry && monitor.geometry.x !== undefined ? monitor.geometry.x : 0) - preview.bounds.minX) * preview.previewScale)
                    - chrome
                y: (preview.height - preview.bounds.height * preview.previewScale) / 2
                    + (((monitor && monitor.geometry && monitor.geometry.y !== undefined ? monitor.geometry.y : 0) - preview.bounds.minY) * preview.previewScale)
                    - chrome

                Behavior on x { enabled: root.previewReady; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: root.previewReady; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: root.previewReady; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: root.previewReady; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: screenFrame
                    x: chrome
                    y: chrome
                    width: monitorItem.screenW
                    height: monitorItem.screenH
                    radius: laptop ? 10 : 9
                    color: Qt.rgba(0.045, 0.047, 0.052, 1)
                    border.width: 1
                    border.color: active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.72) : Qt.rgba(1, 1, 1, 0.22)
                    Behavior on width { enabled: root.previewReady; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on height { enabled: root.previewReady; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.width: active ? 1 : 0
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
                    }

                    Rectangle {
                        id: screenSurface
                        anchors.fill: parent
                        anchors.margins: laptop ? 8 : 7
                        radius: Math.max(4, parent.radius - 4)
                        color: Qt.rgba(0.12, 0.14, 0.17, 1)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.wallpaperPreviewSource
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            mipmap: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: screenSurface.radius
                            color: Qt.rgba(0, 0, 0, 0.03)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: screenSurface.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.13) }
                                GradientStop { position: 0.45; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
                            }
                        }

                        Text {
                            anchors { left: parent.left; top: parent.top; margins: 7 }
                            text: monitor.name
                            color: Qt.rgba(1, 1, 1, 0.88)
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.letterSpacing: 0
                        }
                    }
                }

                Rectangle {
                    visible: !laptop
                    anchors.horizontalCenter: screenFrame.horizontalCenter
                    y: screenFrame.y + screenFrame.height + 1
                    width: Math.max(13, screenFrame.width * 0.075)
                    height: 22
                    radius: 4
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.08) }
                    }
                }

                Rectangle {
                    visible: !laptop
                    anchors.horizontalCenter: screenFrame.horizontalCenter
                    y: screenFrame.y + screenFrame.height + 23
                    width: Math.max(64, screenFrame.width * 0.34)
                    height: 6
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.16)
                }

                Rectangle {
                    visible: laptop
                    anchors.horizontalCenter: screenFrame.horizontalCenter
                    y: screenFrame.y + screenFrame.height + 3
                    width: screenFrame.width + 24
                    height: 10
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.17)

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(24, parent.width * 0.18)
                        height: 3
                        radius: 2
                        color: Qt.rgba(0, 0, 0, 0.24)
                    }
                }

            }
        }
    }

    // ── Estados de carregamento / erro ────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: root.loading
        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.loading_monitor_infoa"]) || "Loading monitor info…")
        color: root.textSecondary
        font.pixelSize: Theme.fontSizeNormal
    }

    Text {
        anchors.centerIn: parent
        visible: !root.loading && root.errorMessage !== ""
        text: "⚠  " + root.errorMessage
        color: root.errorColor
        font.pixelSize: Theme.fontSizeNormal
        wrapMode: Text.WordWrap
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Layout principal ──────────────────────────────────────────────────
    ScrollPage {
        anchors.fill: parent
        contentMargins: 28
        maxWidth: 1000
        visible: !root.loading && root.errorMessage === "" && root.mon !== null

        ColumnLayout {
            width: parent.width
            spacing: 0

            ColumnLayout {
                id: previewColumn
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                spacing: 16

                SectionHeader {
                    Layout.fillWidth: true
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.display_preview"]) || "DISPLAY PREVIEW")
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: previewDevice.implicitHeight + 24

                    Column {
                        id: previewDevice
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: 14

                        DisplayPreview {
                            width: Math.min(620, previewColumn.width)
                        }

                        Column {
                            width: Math.min(620, previewColumn.width)
                            spacing: 5

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root._displayTitle(root.mon)
                                color: root.textPrimary
                                font { pixelSize: 22; weight: Font.DemiBold; letterSpacing: 0 }
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root._displaySubtitle(root.mon)
                                color: root.textSecondary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root.mon && root._selectedResolutionLabel() !== ""
                                    ? root._selectedResolutionLabel().replace("x", "×") + " • " + root._currentRefreshLabel()
                                    : ""
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // Monitor selector
            ColumnLayout {
                visible: root.monitors.length > 1
                Layout.fillWidth: true
                spacing: 6
                Layout.bottomMargin: 24

                SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.monitor"]) || "MONITOR") }
                SelectButton {
                    Layout.fillWidth: true
                    label: root.mon ? _monitorLabel(root.mon) : ""
                    options: root.monitors.map(m => _monitorLabel(m))
                    selectedIndex: root.activeMonitor
                    onSelected: (i) => { root.activeMonitor = i; root._applyCurrentValues() }
                }
            }

            // Resolution
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Layout.bottomMargin: 24

                SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.resolution"]) || "RESOLUTION"); Layout.bottomMargin: 8 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: root.showAllResolutions
                            ? Array.from({ length: root.mon && root.mon.resolutions ? root.mon.resolutions.length : 0 }, (_, i) => root.mon.resolutions.length - 1 - i)
                            : root.defaultResolutionIndices

                        delegate: Rectangle {
                            readonly property int    realIndex: modelData
                            readonly property bool   active:    realIndex === root.selectedResolution
                            readonly property bool   isNative:  realIndex === ((root.mon && root.mon.resolutions ? root.mon.resolutions.length : 0) - 1)
                            readonly property string resText:   root.mon && root.mon.resolutions && root.mon.resolutions[realIndex] ? root.mon.resolutions[realIndex].replace("x", "×") : ""

                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 8
                            color: active
                                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
                                : rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            border.width: active ? 1 : 0
                            border.color: root.accent
                            Behavior on color        { ColorAnimation { duration: 110 } }
                            Behavior on border.color { ColorAnimation { duration: 110 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                spacing: 8

                                Text {
                                    text: resText
                                    color: active ? root.accent : root.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.weight: active ? Font.Medium : Font.Normal
                                    Behavior on color { ColorAnimation { duration: 110 } }
                                }

                                Rectangle {
                                    visible: isNative
                                    implicitWidth:  nativeLbl.implicitWidth + 10
                                    implicitHeight: 16
                                    radius: 4
                                    color: active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                    Text {
                                        id: nativeLbl
                                        anchors.centerIn: parent
                                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.default"]) || "Default")
                                        color: active ? root.accent : root.textSecondary
                                        font { pixelSize: 10; weight: Font.Medium; letterSpacing: 0 }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                                Text { visible: active; text: "✓"; color: root.accent; font.pixelSize: 12 }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedResolution = realIndex
                            }
                        }
                    }
                }

                Text {
                    visible: root.mon &&
                             root.mon.resolutions.length > root.defaultResolutionIndices.length
                    Layout.topMargin: 6
                    text: root.showAllResolutions ? "⌃  Show less" : "⌄  Show all resolutions"
                    color: toggleResArea.containsMouse ? Qt.lighter(root.accent, 1.2) : root.textSecondary
                    font { pixelSize: 11; weight: Font.Medium }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: toggleResArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showAllResolutions = !root.showAllResolutions
                    }
                }
            }

            // Settings card
            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12
                color: root.cardBg
                border { width: 1; color: root.cardBorder }
                implicitHeight: settingsCol.implicitHeight

                ColumnLayout {
                    id: settingsCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.refresh_rate"]) || "Refresh rate")
                        isLast: false
                        SelectButton {
                            implicitWidth: 130
                            label: root._currentRefreshLabel()
                            options: root.currentHzList.map(hz => hz + " Hz")
                            selectedIndex: root.selectedHz
                            onSelected: (i) => root.selectedHz = i
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.color_depth"]) || "Color depth")
                        isLast: false
                        SelectButton {
                            implicitWidth: 130
                            label: root.mon ? root.mon.bitdepths[root.selectedBitdepth] + " bpc" : "—"
                            options: root.mon && root.mon.bitdepths ? root.mon.bitdepths.map(b => b + " bpc") : []
                            selectedIndex: root.selectedBitdepth
                            onSelected: (i) => root.selectedBitdepth = i
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.variable_refresh_rate"]) || "Variable Refresh Rate")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.sublabel.vrr_freesync_g_sync_mode_when_supported_by_the_d"]) || "VRR / FreeSync / G-Sync mode when supported by the display")
                        isLast: false
                        visible: root.mon && root.mon.vrrSupported ? true : false

                        SelectButton {
                            implicitWidth: 160
                            label: root._currentVrrLabel()
                            options: root.vrrModeOptions.map(option => option.label)
                            selectedIndex: root.selectedVrrMode
                            onSelected: (i) => root.selectedVrrMode = i
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.display_scale"]) || "Display scale")
                        isLast: true
                        SelectButton {
                            implicitWidth: 130
                            label: root.mon ? root.mon.scales[root.selectedScale] + "×" : "—"
                            options: root.mon && root.mon.scales ? root.mon.scales.map(s => s + "×") : []
                            selectedIndex: root.selectedScale
                            onSelected: (i) => root.selectedScale = i
                        }
                    }
                }
            }

            SectionHeader {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.color_night_shift"]) || "COLOR & NIGHT SHIFT")
                Layout.bottomMargin: 12
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12
                color: root.cardBg
                border { width: 1; color: root.cardBorder }
                implicitHeight: colorCol.implicitHeight

                ColumnLayout {
                    id: colorCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.night_shift"]) || "Night Shift")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.sublabel.warm_screen_colors_to_reduce_blue_light_at_night"]) || "Warm screen colors to reduce blue light at night")
                        isLast: false

                        ToggleSwitch {
                            checked: root.nightShiftEnabled
                            onToggled: root.nightShiftEnabled = !root.nightShiftEnabled
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.night_shift_strength"]) || "Night Shift strength")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.sublabel.how_warm_the_image_should_look_when_enabled"]) || "How warm the image should look when enabled")
                        isLast: false

                        Row {
                            spacing: 10

                            ValueSlider {
                                width: 220
                                minValue: 0
                                maxValue: 100
                                stepSize: 1
                                value: root.nightShiftStrength
                                enabled: root.nightShiftEnabled
                                opacity: root.nightShiftEnabled ? 1 : 0.45
                                onValueModified: (value) => root.nightShiftStrength = Math.round(value)
                                onEditingFinished: (_) => root.queueLiveColorApply("night-shift-only")
                            }

                            Text {
                                width: 44
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.nightShiftStrength + "%"
                                color: root.textSecondary
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.schedule"]) || "Schedule")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.sublabel.turn_night_shift_on_and_off_automatically"]) || "Turn Night Shift on and off automatically")
                        isLast: false

                        ToggleSwitch {
                            checked: root.nightShiftScheduleEnabled
                            onToggled: root.nightShiftScheduleEnabled = !root.nightShiftScheduleEnabled
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.start"]) || "Start")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.sublabel.when_night_shift_should_turn_on"]) || "When Night Shift should turn on")
                        isLast: false
                        visible: root.nightShiftScheduleEnabled

                        Row {
                            spacing: 8

                            SelectButton {
                                implicitWidth: 72
                                label: root._timeHour(root.nightShiftStart)
                                options: root.hourOptions
                                selectedIndex: root.hourOptions.indexOf(root._timeHour(root.nightShiftStart))
                                onSelected: (i) => root._setTimeHour("nightShiftStart", root.hourOptions[i])
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ":"
                                color: root.textSecondary
                                font.pixelSize: 14
                            }

                            SelectButton {
                                implicitWidth: 72
                                label: root._timeMinute(root.nightShiftStart)
                                options: root.minuteOptions
                                selectedIndex: Math.max(0, root.minuteOptions.indexOf(root._timeMinute(root.nightShiftStart)))
                                onSelected: (i) => root._setTimeMinute("nightShiftStart", root.minuteOptions[i])
                            }
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.end"]) || "End")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.sublabel.when_night_shift_should_turn_off"]) || "When Night Shift should turn off")
                        isLast: false
                        visible: root.nightShiftScheduleEnabled

                        Row {
                            spacing: 8

                            SelectButton {
                                implicitWidth: 72
                                label: root._timeHour(root.nightShiftEnd)
                                options: root.hourOptions
                                selectedIndex: root.hourOptions.indexOf(root._timeHour(root.nightShiftEnd))
                                onSelected: (i) => root._setTimeHour("nightShiftEnd", root.hourOptions[i])
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ":"
                                color: root.textSecondary
                                font.pixelSize: 14
                            }

                            SelectButton {
                                implicitWidth: 72
                                label: root._timeMinute(root.nightShiftEnd)
                                options: root.minuteOptions
                                selectedIndex: Math.max(0, root.minuteOptions.indexOf(root._timeMinute(root.nightShiftEnd)))
                                onSelected: (i) => root._setTimeMinute("nightShiftEnd", root.minuteOptions[i])
                            }
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.label.saturation"]) || "Saturation")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.sublabel.display_vibrance_powered_by_nvibrant"]) || "Display vibrance powered by nvibrant")
                        isLast: true

                        Row {
                            spacing: 10

                            ValueSlider {
                                width: 220
                                minValue: 0
                                maxValue: 100
                                stepSize: 1
                                value: root.selectedSaturation
                                onValueModified: (value) => root.selectedSaturation = Math.round(value)
                            }

                            Text {
                                width: 52
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.selectedSaturation + "%"
                                color: root.textSecondary
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            // Apply bar
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                spacing: 12

                Item { Layout.fillWidth: true }

                Text {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.a_applied"]) || "✓ Applied")
                    color: root.accent
                    font { pixelSize: Theme.fontSizeNormal; weight: Font.Medium }
                    opacity: root.savedVisible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Rectangle {
                    implicitWidth: applyLbl.implicitWidth + 32
                    implicitHeight: 34
                    radius: 8
                    color: applyArea.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: applyLbl
                        anchors.centerIn: parent
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.display.text.apply"]) || "Apply")
                        color: Theme.accentForeground
                        font { pixelSize: Theme.fontSizeNormal; weight: Font.Medium }
                    }
                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveSettings()
                    }
                }
            }
        }
    }
}
