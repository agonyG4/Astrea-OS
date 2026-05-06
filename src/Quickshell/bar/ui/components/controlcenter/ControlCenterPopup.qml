import Quickshell
import Quickshell.Io
import QtQuick
import Qt5Compat.GraphicalEffects
import "../system" as SystemComponents
import "../../.."

SystemComponents.TopbarPopup {
    id: control

    property bool netConnected: false
    property string netType: "none"
    property string ssid: ""
    property bool btOn: false
    property string btDevicesJson: "[]"
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
    property bool customizeMode: false
    readonly property string layoutStateDir: Quickshell.env("HOME") + "/.local/state/Astrea"

    readonly property var parsedBtDevices: {
        try { return JSON.parse(btDevicesJson) } catch(e) { return [] }
    }
    readonly property int connectedBtCount: parsedBtDevices.filter(d => d.connected === true).length
    readonly property string wifiTitle: netType === "wifi" && ssid !== "" ? ssid : "Wi-Fi"
    readonly property string wifiSubtitle: !netConnected ? "Desconectado" : (netType === "wifi" ? "Conectado" : "Ethernet ativo")
    readonly property string bluetoothSubtitle: !btOn ? "Desligado" : (connectedBtCount > 0 ? connectedBtCount + " conectado" : "Ligado")
    readonly property bool hasMusic: musicState && musicState.musicTitleText !== ""
    readonly property string musicTitle: hasMusic ? musicState.musicTitleText : "Nada tocando"
    readonly property string musicArtist: hasMusic ? musicState.musicArtistText : "Spotify"
    readonly property string musicArt: hasMusic ? musicState.artSource : ""
    readonly property bool musicPlaying: musicState ? musicState.isPlaying : false

    readonly property color popupGlass: Theme.background
    readonly property color popupWash: "transparent"
    readonly property color popupBorder: Theme.border

    signal volumeChangeHandled(int v)
    signal muteChangeHandled(bool muted)

    popupWidth: 356
    cardPadding: 16
    contentSpacing: 12
    backgroundColor: control.popupGlass
    washColor: control.popupWash
    borderColor: control.popupBorder
    floatingAccessoryGap: 8
    floatingAccessoryRightMargin: 2
    floatingAccessory: Component {
        Rectangle {
            id: customizeFloat

            implicitWidth: customizeRow.implicitWidth + 22
            implicitHeight: 30
            radius: 15
            color: control.customizeMode
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, customizeFloatArea.containsMouse ? 0.34 : 0.26)
                : (customizeFloatArea.containsMouse ? Theme.surface : Theme.background)
            border.width: 1
            border.color: control.customizeMode
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.52)
                : Theme.border

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            Row {
                id: customizeRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.customizeMode ? "󰅖" : "󰏫"
                    color: control.customizeMode ? Theme.iconActive : Theme.iconMain
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.customizeMode ? "Concluir" : "Customizar"
                    color: Theme.textActive
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

    function blockHeight(kind) {
        return kind === "main" ? 160 : 72
    }

    function blockLabel(kind) {
        if (kind === "main")
            return "Conectividade e mídia"
        if (kind === "volume")
            return "Volume"
        return "Brilho"
    }

    function applyLayoutOrder(order) {
        const allowed = ["main", "volume", "brightness"]
        const seen = {}
        layoutModel.clear()

        for (let i = 0; i < order.length; i++) {
            const kind = order[i]
            if (allowed.indexOf(kind) !== -1 && !seen[kind]) {
                layoutModel.append({ "kind": kind })
                seen[kind] = true
            }
        }

        for (let j = 0; j < allowed.length; j++) {
            const fallbackKind = allowed[j]
            if (!seen[fallbackKind])
                layoutModel.append({ "kind": fallbackKind })
        }
    }

    function currentLayoutOrder() {
        const order = []
        for (let i = 0; i < layoutModel.count; i++)
            order.push(layoutModel.get(i).kind)
        return order
    }

    function saveLayout() {
        layoutSaveProc.payload = JSON.stringify({ order: currentLayoutOrder() })
        layoutSaveProc.running = false
        layoutSaveProc.running = true
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
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
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
        command: ["bash", "-c", "cat \"$1/control-center-layout.json\" 2>/dev/null || true", "--", control.layoutStateDir]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (trimmed === "")
                    return

                try {
                    const parsed = JSON.parse(trimmed)
                    if (parsed && parsed.order)
                        control.applyLayoutOrder(parsed.order)
                } catch(e) {}
            }
        }
    }

    Process {
        id: layoutSaveProc
        property string payload: ""
        command: ["bash", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/control-center-layout.json\"", "--", control.layoutStateDir, payload]
        running: false
    }

    Component.onCompleted: layoutLoadProc.running = true

    ListModel {
        id: layoutModel
        ListElement { kind: "main" }
        ListElement { kind: "volume" }
        ListElement { kind: "brightness" }
    }

    Item {
        width: parent.width
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Central de Controle"
            color: Theme.textActive
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeTitle
                weight: Font.DemiBold
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 15
            color: Theme.surface

            Text {
                anchors.centerIn: parent
                text: "󰃠"
                color: Theme.textDim
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeIcon
                }
            }
        }
    }

    ReorderableStack {
        id: blockStack
        width: parent.width
        model: layoutModel
        editMode: control.customizeMode
        itemSpacing: control.contentSpacing
        itemHeightProvider: key => control.blockHeight(key)
        itemLabelProvider: key => control.blockLabel(key)
        itemDelegate: controlCenterBlockDelegate
        editOverlayRadius: Theme.radiusLarge
        labelColor: Theme.textSecondary
        labelFontFamily: Theme.fontFamily
        labelPixelSize: Theme.fontSizeMicro
        onItemDropped: control.saveLayout()
    }

    Component {
        id: controlCenterBlockDelegate

        Item {
            property string itemKey: ""

            Loader {
                anchors.fill: parent
                sourceComponent: itemKey === "main"
                    ? mainBlockComponent
                    : itemKey === "volume"
                        ? volumeBlockComponent
                        : brightnessBlockComponent
            }
        }
    }

    Component {
        id: mainBlockComponent

        Item {
            Row {
                anchors.fill: parent
                spacing: 10

                ConnectivityCard {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                }

                MediaCard {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    title: control.musicTitle
                    artist: control.musicArtist
                    artSource: control.musicArt
                    playing: control.musicPlaying
                    active: control.hasMusic
                    onPreviousClicked: control.previousTrack()
                    onPlayClicked: control.playPause()
                    onNextClicked: control.nextTrack()
                }
            }
        }
    }

    Component {
        id: volumeBlockComponent

        SliderCard {
            title: "Volume"
            leftIcon: control.volumeIcon()
            rightIcon: control.masterMuted ? "󰝟" : "󰕾"
            value: control.masterVol
            muted: control.masterMuted
            animateValue: control.sliderAnimationsEnabled
            onValueChangedByUser: v => control.applyVolume(v)
            onWheelChangedByUser: delta => control.applyVolume(control.masterVol + delta * 2)
            onIconClicked: control.toggleMute()
        }
    }

    Component {
        id: brightnessBlockComponent

        SliderCard {
            title: "Brilho"
            leftIcon: "󰃞"
            rightIcon: "󰃠"
            value: control.brightness
            muted: false
            animateValue: control.sliderAnimationsEnabled
            onValueChangedByUser: v => control.applyBrightness(v)
            onWheelChangedByUser: delta => control.applyBrightness(control.brightness + delta * control.brightnessStep)
        }
    }

    component MediaCard: Rectangle {
        id: mediaCard

        property string title: ""
        property string artist: ""
        property string artSource: ""
        property bool playing: false
        property bool active: false
        signal previousClicked()
        signal playClicked()
        signal nextClicked()

        implicitHeight: 160
        radius: Theme.radiusLarge
        color: active ? Theme.surface : Theme.background
        border.width: 1
        border.color: active ? Theme.barBorderHover : Theme.border

        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        Rectangle {
            id: mediaArt
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.topMargin: 12
            width: 46
            height: 46
            radius: 12
            clip: true
            color: Theme.surface

            Rectangle {
                id: mediaArtMask
                anchors.fill: parent
                radius: 12
                visible: false
            }

            Image {
                anchors.fill: parent
                source: mediaCard.artSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                cache: false
                asynchronous: true
                visible: mediaCard.artSource !== ""
                layer.enabled: true
                layer.effect: OpacityMask { maskSource: mediaArtMask }
            }

            Text {
                anchors.centerIn: parent
                visible: mediaCard.artSource === ""
                text: "󰝚"
                color: Theme.iconMain
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIconLarge }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: mediaArt.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            anchors.topMargin: 14
            spacing: 3

            Text {
                width: parent.width
                text: mediaCard.title
                color: Theme.textActive
                elide: Text.ElideRight
                maximumLineCount: 1
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeTitle; weight: Font.DemiBold }
            }

            Text {
                width: parent.width
                text: mediaCard.artist
                color: Theme.textSecondary
                elide: Text.ElideRight
                opacity: 0.9
                maximumLineCount: 1
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody; weight: Font.Medium }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 15
            anchors.bottomMargin: 14
            spacing: 14

            MediaButton {
                icon: "󰒮"
                enabled: mediaCard.active
                onClicked: mediaCard.previousClicked()
            }

            MediaButton {
                icon: mediaCard.playing ? "󰏤" : "󰐊"
                enabled: mediaCard.active
                primary: true
                onClicked: mediaCard.playClicked()
            }

            MediaButton {
                icon: "󰒭"
                enabled: mediaCard.active
                onClicked: mediaCard.nextClicked()
            }
        }
    }

    component MediaButton: Rectangle {
        id: mediaButton

        property string icon: ""
        property bool primary: false
        signal clicked()

        width: primary ? 38 : 30
        height: primary ? 38 : 30
        radius: width / 2
        color: !enabled ? Theme.background
                        : primary ? (mediaArea.containsMouse ? Theme.barBorderHover : Theme.surface)
                                  : (mediaArea.containsMouse ? Theme.separator : "transparent")
        opacity: enabled ? 1 : 0.38

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: mediaButton.icon
            color: Theme.iconMain
            font { family: Theme.fontFamily; pixelSize: mediaButton.primary ? Theme.fontSizeIconLarge : Theme.fontSizeIcon }
        }

        MouseArea {
            id: mediaArea
            anchors.fill: parent
            enabled: mediaButton.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaButton.clicked()
        }
    }

    component ConnectivityCard: Rectangle {
        id: connectivityCard

        radius: Theme.radiusLarge
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            ConnectivityRow {
                width: parent.width
                height: (parent.height - parent.spacing * 2) / 3
                icon: control.netConnected && control.netType !== "none"
                    ? (control.netType === "wifi" ? "󰖩" : "󰈀")
                    : "󰖪"
                title: control.wifiTitle
                subtitle: control.wifiSubtitle
                active: control.netConnected && control.netType === "wifi"
                onClicked: control.toggleWifi()
            }

            ConnectivityRow {
                width: parent.width
                height: (parent.height - parent.spacing * 2) / 3
                icon: control.btOn ? "󰂯" : "󰂲"
                title: "Bluetooth"
                subtitle: control.bluetoothSubtitle
                active: control.btOn
                onClicked: control.toggleBluetooth()
            }

            ConnectivityRow {
                width: parent.width
                height: (parent.height - parent.spacing * 2) / 3
                icon: "󰀝"
                title: "AirDrop"
                subtitle: control.airdropOn ? "Ativo" : "Desativado"
                active: control.airdropOn
                onClicked: control.airdropOn = !control.airdropOn
            }
        }
    }

    component ConnectivityRow: Rectangle {
        id: rowRoot

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        signal clicked()

        radius: Theme.radiusMedium
        color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                      : (rowMouse.containsMouse ? Theme.separator : "transparent")

        Behavior on color { ColorAnimation { duration: 130 } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 7
            spacing: 8

            Rectangle {
                width: 28
                height: 28
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: rowRoot.active ? Theme.iconActive : Theme.surface

                Text {
                    anchors.centerIn: parent
                    text: rowRoot.icon
                    color: rowRoot.active ? Theme.background : Theme.iconMain
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
                }
            }

            Column {
                width: parent.width - 36
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    width: parent.width
                    text: rowRoot.title
                    color: Theme.textActive
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.DemiBold }
                }

                Text {
                    width: parent.width
                    text: rowRoot.subtitle
                    color: Theme.textSecondary
                    opacity: 0.9
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMicro; weight: Font.Medium }
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rowRoot.clicked()
        }
    }

    component ControlTile: Rectangle {
        id: tile

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        signal clicked()

        radius: Theme.radiusMedium
        color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                      : (tileMouse.containsMouse ? Theme.separator : Theme.background)
        border.width: 1
        border.color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.36) : Theme.border

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 9

            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: tile.active ? Theme.iconActive : Theme.surface

                Text {
                    anchors.centerIn: parent
                    text: tile.icon
                    color: tile.active ? Theme.background : Theme.iconMain
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
                }
            }

            Column {
                width: parent.width - 39
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: tile.title
                    color: Theme.textActive
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.DemiBold }
                }

                Text {
                    width: parent.width
                    text: tile.subtitle
                    color: Theme.textSecondary
                    opacity: 0.9
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption }
                }
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    component SliderCard: Rectangle {
        id: sliderCard

        property string title: ""
        property string leftIcon: ""
        property string rightIcon: ""
        property int value: 0
        property bool muted: false
        property bool animateValue: false
        signal valueChangedByUser(int value)
        signal wheelChangedByUser(int delta)
        signal iconClicked()

        height: 72
        radius: Theme.radiusLarge
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.topMargin: 9
            text: sliderCard.title
            color: Theme.textActive
            opacity: 0.86
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.DemiBold }
        }

        Text {
            id: sliderLeftIcon
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.bottomMargin: 12
            text: sliderCard.leftIcon
            color: sliderCard.muted ? Theme.iconMuted : Theme.iconMain
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sliderCard.iconClicked()
            }
        }

        Item {
            id: sliderArea
            anchors.left: sliderLeftIcon.right
            anchors.right: sliderRightIcon.left
            anchors.verticalCenter: sliderLeftIcon.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 24

            Rectangle {
                id: sliderTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.separator

                Rectangle {
                    width: Math.max(radius * 2, sliderTrack.width * (sliderCard.value / 100))
                    height: parent.height
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: sliderCard.muted ? Theme.iconMuted : Theme.iconMain }
                        GradientStop { position: 1.0; color: sliderCard.muted ? Theme.iconMuted : Theme.iconActive }
                    }
                    Behavior on width {
                        enabled: sliderCard.animateValue
                        NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(sliderTrack.width - width, sliderTrack.width * (sliderCard.value / 100) - width / 2))
                width: sliderMouse.pressed ? 20 : (sliderMouse.containsMouse ? 18 : 14)
                height: width
                radius: width / 2
                color: Theme.iconActive

                Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Behavior on x {
                    enabled: !sliderMouse.pressed && sliderCard.animateValue
                    NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.border
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                anchors.topMargin: -10
                anchors.bottomMargin: -10
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor

                onPressed: e => sliderCard.valueChangedByUser(control.volumePercentFromX(e.x, sliderTrack.width))
                onPositionChanged: e => {
                    if (pressed)
                        sliderCard.valueChangedByUser(control.volumePercentFromX(e.x, sliderTrack.width))
                }
                onWheel: e => sliderCard.wheelChangedByUser(e.angleDelta.y > 0 ? 1 : -1)
            }
        }

        Text {
            id: sliderRightIcon
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
            text: sliderCard.rightIcon
            color: sliderCard.muted ? Theme.iconMuted : Theme.iconMain
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
        }
    }
}
