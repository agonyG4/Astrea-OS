import Quickshell
import Quickshell.Io
import QtQuick
import "../system/popups" as SystemComponents
import "../../.."
import "."
import "modules"
import "../../../../AstreaI18n" as AstreaI18n
import "ControlCenterRegistry.js" as ModuleRegistry

SystemComponents.TopbarPopup {
    id: control

    property bool netConnected: false
    property string netType: "none"
    property string ssid: ""
    property bool btOn: false
    property string btDevicesJson: "[]"
    property bool btScanning: false
    property var btProcess: null
    property var netProcess: null
    property int masterVol: 50
    property bool masterMuted: false
    property var musicState: null
    property int brightness: 100
    property int ddcBus: 3
    property int brightnessStep: 5
    property bool sliderAnimationsEnabled: false
    property bool airdropOn: false
    property bool focusOn: false
    property bool customizeMode: false
    readonly property int layoutVersion: ModuleRegistry.schemaVersion
    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + ""
    readonly property string stateJsonScript: astreaRoot + "/Core/bridge/state_json.py"
    readonly property string layoutStateDir: Quickshell.env("HOME") + "/.local/state/Astrea"
    readonly property string layoutStatePath: layoutStateDir + "/control-center-layout.json"

    readonly property var parsedBtDevices: {
        try { return JSON.parse(btDevicesJson) } catch(e) { return [] }
    }
    readonly property int connectedBtCount: parsedBtDevices.filter(d => d.connected === true).length
    readonly property bool btPowerPending: btProcess ? btProcess.powerPending : false
    readonly property string btPowerError: btProcess ? btProcess.powerError : ""
    readonly property string wifiTitle: netType === "wifi" && ssid !== "" ? ssid : "Wi-Fi"
    readonly property string wifiSubtitle: !netConnected
        ? tr("quickshell.bar.ui.components.controlcenter.status.disconnected", "Disconnected")
        : (netType === "wifi"
            ? tr("quickshell.bar.ui.components.controlcenter.status.connected", "Connected")
            : tr("quickshell.bar.ui.components.controlcenter.status.ethernet_active", "Ethernet active"))
    readonly property string bluetoothSubtitle: btPowerError !== "" ? btPowerError
        : btPowerPending ? tr("quickshell.bar.ui.components.controlcenter.status.changing", "Changing...")
        : !btOn ? tr("quickshell.bar.ui.components.controlcenter.status.off", "Off")
        : btScanning && connectedBtCount === 0 ? tr("quickshell.bar.ui.components.controlcenter.status.searching", "Searching...")
        : connectedBtCount > 0 ? tr("quickshell.bar.ui.components.controlcenter.status.connected_count", "{count} connected", { count: connectedBtCount })
        : tr("quickshell.bar.ui.components.controlcenter.status.on", "On")
    readonly property bool hasMusic: musicState && musicState.musicTitleText !== ""
    readonly property string musicTitle: hasMusic ? musicState.musicTitleText : tr("quickshell.bar.ui.components.controlcenter.media.nothing_playing", "Nothing playing")
    readonly property string musicArtist: hasMusic ? musicState.musicArtistText : tr("quickshell.bar.ui.components.controlcenter.media.no_app", "Media")
    readonly property string musicArt: hasMusic ? musicState.artSource : ""
    readonly property bool musicPlaying: musicState ? musicState.isPlaying : false

    readonly property color popupGlass: Theme.background
    readonly property color popupWash: "transparent"
    readonly property color popupBorder: Theme.border
    readonly property int fixedContentHeight: 416

    signal volumeChangeHandled(int v)
    signal muteChangeHandled(bool muted)

    popupWidth: 332
    cardPadding: 12
    cardRadius: 18
    contentSpacing: Theme.spacing
    backgroundColor: control.popupGlass
    washColor: control.popupWash
    borderColor: control.popupBorder
    floatingAccessoryGap: Theme.spacing
    floatingAccessoryRightMargin: 2
    floatingAccessory: Component {
        Rectangle {
            id: customizeFloat

            implicitWidth: customizeRow.implicitWidth + 22
            implicitHeight: 30
            radius: height / 2
            color: control.customizeMode
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, customizeFloatArea.containsMouse ? 0.34 : 0.26)
                : (customizeFloatArea.containsMouse ? Theme.surface : Theme.background)
            border.width: 1
            border.color: control.customizeMode
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.52)
                : Theme.border

            Behavior on color { ColorAnimation { duration: Theme.animationHover } }
            Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }

            Row {
                id: customizeRow
                anchors.centerIn: parent
                spacing: Theme.spacingSmall

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.customizeMode ? "󰅖" : "󰏫"
                    color: control.customizeMode ? Theme.shellIconActive : Theme.shellIconMain
                    font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeSmall }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.customizeMode
                        ? control.tr("quickshell.bar.ui.components.controlcenter.action.done", "Done")
                        : control.tr("quickshell.bar.ui.components.controlcenter.action.edit_controls", "Edit controls")
                    color: Theme.shellTextActive
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold }
                }
            }

            MouseArea {
                id: customizeFloatArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    control.customizeMode = !control.customizeMode
                    if (!control.customizeMode)
                        control.saveLayout()
                }
            }
        }
    }

    function tr(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    function volumePercentFromX(x, width) {
        return Math.round(Math.max(0, Math.min(width, x)) / width * 100)
    }

    function volumeIcon() {
        if (masterMuted || masterVol === 0)
            return "󰝟"
        if (masterVol < 34)
            return "󰕿"
        if (masterVol < 67)
            return "󰖀"
        return "󰕾"
    }

    function applyVolume(value) {
        const nextValue = Math.round(Math.max(0, Math.min(100, value)))
        if (nextValue === control.masterVol)
            return

        control.masterVol = nextValue
        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", nextValue + "%"]
        volSetProc.running = false
        volSetProc.running = true
        control.volumeChangeHandled(nextValue)
    }

    function toggleMute() {
        control.masterMuted = !control.masterMuted
        volMuteProc.running = false
        volMuteProc.running = true
        control.muteChangeHandled(control.masterMuted)
    }

    function playPause() {
        if (control.musicState)
            control.musicState.playPause()
    }

    function nextTrack() {
        if (control.musicState)
            control.musicState.next()
    }

    function previousTrack() {
        if (control.musicState)
            control.musicState.prev()
    }

    function queueBrightnessRead() {
        brightReadProc.running = false
        brightReadProc.running = true
    }

    function scheduleBrightnessUpdate(value) {
        if (!brightSetProc.running) {
            brightSetProc.command = control.brightnessCommand(value)
            brightSetProc.running = true
        } else {
            brightSetProc.pendingVal = value
            brightSetProc.updatePending = true
        }
    }

    function brightnessCommand(value) {
        return [
            "ddcutil", "--bus", control.ddcBus.toString(), "setvcp", "10",
            value.toString(),
            "--noverify", "--sleep-multiplier=0.05"
        ]
    }

    function applyBrightness(value) {
        const nextValue = Math.round(Math.max(0, Math.min(100, value)))
        if (nextValue === control.brightness)
            return

        control.brightness = nextValue
        control.scheduleBrightnessUpdate(nextValue)
    }

    function toggleWifi() {
        wifiPowerProc.turnOn = !(control.netConnected && control.netType === "wifi")
        wifiPowerProc.running = false
        wifiPowerProc.running = true
    }

    function toggleBluetooth() {
        if (!control.btProcess)
            return
        control.btProcess.setPower(!control.btOn)
        if (!control.btOn && control.shown)
            control.btProcess.requestScan("control-center")
    }

    function moduleHeight(kind, size, group) {
        return ModuleRegistry.moduleHeight(kind, size)
    }

    function moduleLabel(kind, size, group) {
        return ModuleRegistry.moduleLabel(kind)
    }

    function moduleSpan(kind, size, group) {
        return ModuleRegistry.moduleSpan(kind)
    }

    function applyLayoutModules(modules) {
        const seen = {}
        layoutModel.clear()

        const incoming = modules && modules.length > 0 ? ModuleRegistry.migrateModules(modules) : ModuleRegistry.cloneDefaultModules()
        for (let i = 0; i < incoming.length; i++) {
            const normalized = ModuleRegistry.normalizeModule(incoming[i])
            if (normalized && !seen[normalized.moduleId]) {
                layoutModel.append(normalized)
                seen[normalized.moduleId] = true
            }
        }

        if (layoutModel.count === 0)
            applyLayoutModules(ModuleRegistry.cloneDefaultModules())
    }

    function currentLayoutModules() {
        const modules = []
        for (let i = 0; i < layoutModel.count; i++) {
            const row = layoutModel.get(i)
            modules.push({
                "moduleId": row.moduleId,
                "kind": row.kind,
                "size": row.size,
                "group": row.group,
                "slot": row.slot
            })
        }
        return modules
    }

    function hasModuleKind(kind) {
        for (let i = 0; i < layoutModel.count; i++) {
            if (layoutModel.get(i).kind === kind)
                return true
        }
        return false
    }

    function nextModuleId(kind) {
        let index = 1
        while (true) {
            const candidate = index === 1 ? kind : kind + "-" + index
            let exists = false
            for (let i = 0; i < layoutModel.count; i++) {
                if (layoutModel.get(i).moduleId === candidate) {
                    exists = true
                    break
                }
            }
            if (!exists)
                return candidate
            index++
        }
    }

    function addModule(kind) {
        const module = ModuleRegistry.createModule(kind)
        if (!module)
            return

        module.moduleId = control.nextModuleId(kind)
        const nextSlot = blockStack.nextAvailableSlotForKind(kind)
        module.slot = nextSlot
        layoutModel.append(module)
        queueLayoutSave()
    }

    function removeModule(moduleId) {
        if (layoutModel.count <= 1)
            return

        for (let i = 0; i < layoutModel.count; i++) {
            const row = layoutModel.get(i)
            const rowKey = row.moduleId !== "" ? row.moduleId : row.kind
            if (rowKey === moduleId) {
                layoutModel.remove(i)
                queueLayoutSave()
                return
            }
        }
    }

    function saveLayout() {
        layoutSaveProc.payload = JSON.stringify({ version: control.layoutVersion, modules: currentLayoutModules() })
        layoutSaveProc.running = false
        layoutSaveProc.running = true
    }

    function moduleComponent(kind) {
        if (kind === "wifi" || kind === "bluetooth" || kind === "airdrop" || kind === "focus" || kind === "mirror")
            return controlToggleModuleComponent
        if (kind === "brightness")
            return brightnessModuleComponent
        if (kind === "volume")
            return volumeModuleComponent
        if (kind === "media")
            return mediaModuleComponent
        return null
    }

    function queueLayoutSave() {
        layoutSaveTimer.restart()
    }

    Timer {
        id: openDelay
        interval: 150
        onTriggered: control.queueBrightnessRead()
    }

    Timer {
        id: sliderAnimationDelay
        interval: 260
        onTriggered: control.sliderAnimationsEnabled = true
    }

    Timer {
        id: layoutSaveTimer
        interval: 60
        repeat: false
        onTriggered: control.saveLayout()
    }

    onCustomizeModeChanged: {
        if (!customizeMode)
            control.queueLayoutSave()
    }

    onShownChanged: {
        if (shown) {
            control.sliderAnimationsEnabled = false
            volReadProc.running = false
            volReadProc.running = true
            if (control.btOn && control.btProcess) {
                control.btProcess.refresh()
                control.btProcess.requestScan("control-center")
            }
            openDelay.start()
            sliderAnimationDelay.restart()
        } else {
            if (control.btProcess)
                control.btProcess.releaseScan("control-center")
            if (control.customizeMode) {
                control.customizeMode = false
                control.queueLayoutSave()
            }
            sliderAnimationDelay.stop()
            control.sliderAnimationsEnabled = false
        }
    }

    Process {
        id: brightSetProc
        command: []
        running: false
        property bool updatePending: false
        property int pendingVal: 50

        onRunningChanged: {
            if (!running && updatePending) {
                updatePending = false
                command = control.brightnessCommand(pendingVal)
                running = true
            }
        }
    }

    Process {
        id: brightReadProc
        command: ["ddcutil", "--bus", control.ddcBus.toString(), "getvcp", "10", "--terse"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length >= 4)
                    control.brightness = parseInt(parts[3])
            }
        }
    }

    Process {
        id: volSetProc
        command: []
        running: false
    }

    Process {
        id: volReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                control.masterMuted = data.includes("[MUTED]")
                const m = data.match(/[\d.]+/)
                if (m) {
                    control.masterVol = Math.round(parseFloat(m[0]) * 100)
                    control.volumeChangeHandled(control.masterVol)
                }
                control.muteChangeHandled(control.masterMuted)
            }
        }
    }

    Process {
        id: volMuteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        running: false
    }

    Process {
        id: wifiPowerProc
        property bool turnOn: true
        command: ["nmcli", "radio", "wifi", turnOn ? "on" : "off"]
        running: false
        onExited: if (control.netProcess) control.netProcess.refresh()
    }

    Process {
        id: layoutLoadProc
        command: ["python3", control.stateJsonScript, "read", control.layoutStatePath]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (trimmed === "")
                    return

                try {
                    const parsed = JSON.parse(trimmed)
                    if (parsed && parsed.modules) {
                        control.applyLayoutModules(parsed.modules)
                        if (parsed.version !== control.layoutVersion)
                            control.queueLayoutSave()
                    } else if (parsed && parsed.order) {
                        control.applyLayoutModules(ModuleRegistry.modulesFromLegacyOrder(parsed.order))
                        control.queueLayoutSave()
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: layoutSaveProc
        property string payload: ""
        command: ["python3", control.stateJsonScript, "write", control.layoutStatePath, payload]
        running: false
    }

    Component.onCompleted: layoutLoadProc.running = true

    ListModel {
        id: layoutModel
        ListElement { moduleId: "wifi"; kind: "wifi"; size: "small"; group: ""; slot: 0 }
        ListElement { moduleId: "bluetooth"; kind: "bluetooth"; size: "small"; group: ""; slot: 1 }
        ListElement { moduleId: "airdrop"; kind: "airdrop"; size: "small"; group: ""; slot: 2 }
        ListElement { moduleId: "focus"; kind: "focus"; size: "small"; group: ""; slot: 3 }
        ListElement { moduleId: "mirror"; kind: "mirror"; size: "small"; group: ""; slot: 4 }
        ListElement { moduleId: "brightness"; kind: "brightness"; size: "small"; group: ""; slot: 8 }
        ListElement { moduleId: "volume"; kind: "volume"; size: "small"; group: ""; slot: 12 }
        ListElement { moduleId: "media"; kind: "media"; size: "medium"; group: ""; slot: 16 }
    }

    Flickable {
        id: blockViewport

        width: parent.width
        height: Math.min(blockStack.height, control.fixedContentHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: blockStack.height
        interactive: contentHeight > height

        Behavior on height { NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic } }

        ReorderableStack {
            id: blockStack

            width: blockViewport.width
            model: layoutModel
            editMode: control.customizeMode
            itemSpacing: control.contentSpacing
            itemHeightProvider: (kind, size, group) => control.moduleHeight(kind, size, group)
            itemSpanProvider: (kind, size, group) => control.moduleSpan(kind, size, group)
            itemLabelProvider: (kind, size, group) => control.moduleLabel(kind, size, group)
            itemDelegate: controlCenterBlockDelegate
            editOverlayRadius: Theme.radiusLarge
            editOverlayColor: Qt.rgba(1, 1, 1, 0.035)
            editOverlayBorderColor: Theme.border
            labelColor: Theme.shellTextSecondary
            labelFontFamily: Theme.fontFamily
            labelPixelSize: Theme.fontSizeMicro
            onItemDropped: control.queueLayoutSave()
            onItemMovedToSlot: (key, slot) => {
                for (let i = 0; i < layoutModel.count; i++) {
                    const row = layoutModel.get(i)
                    const rowKey = row.moduleId !== "" ? row.moduleId : row.kind
                    if (rowKey === key) {
                        layoutModel.setProperty(i, "slot", slot)
                        control.queueLayoutSave()
                        return
                    }
                }
            }
            onItemRemoveRequested: key => control.removeModule(key)
        }
    }

    WidgetLibraryOverlay {
        control: control
        open: control.shown && control.customizeMode
        onAddRequested: kind => control.addModule(kind)
        onDoneRequested: control.customizeMode = false
    }

    Component {
        id: controlCenterBlockDelegate

        Item {
            property string itemKey: ""
            property string itemKind: ""
            property string itemSize: ""
            property string itemGroup: ""
            property int itemSlot: -1

            Loader {
                anchors.fill: parent
                sourceComponent: control.moduleComponent(itemKind)
                onLoaded: {
                    if (item && item.control !== undefined)
                        item.control = control
                    if (item && item.moduleKind !== undefined)
                        item.moduleKind = itemKind
                    if (item && item.moduleSize !== undefined)
                        item.moduleSize = itemSize
                    if (item && item.moduleGroup !== undefined)
                        item.moduleGroup = itemGroup
                }
            }
        }
    }

    Component {
        id: controlToggleModuleComponent
        ControlToggleModule {}
    }

    Component {
        id: brightnessModuleComponent
        SliderModule {}
    }

    Component {
        id: volumeModuleComponent
        SliderModule {}
    }

    Component {
        id: mediaModuleComponent
        NowPlayingModule {}
    }
}
