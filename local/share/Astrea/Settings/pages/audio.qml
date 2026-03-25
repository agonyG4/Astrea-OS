import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color accent:        "#0a84ff"
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSecondary: "#98989f"
    readonly property color cardBg:        Qt.rgba(1, 1, 1, 0.05)
    readonly property color cardBorder:    Qt.rgba(1, 1, 1, 0.08)
    readonly property color popupBg:       Qt.rgba(0.13, 0.13, 0.14, 0.97)
    readonly property color errorColor:    "#ff453a"
    readonly property color warningColor:  "#ff9f0a"
    readonly property color successColor:  "#30d158"

    readonly property string _script:
        Quickshell.env("HOME") + "/.local/share/Astrea/System/scripts/get-audio-info.py"

    // ── State ─────────────────────────────────────────────────────────────
    property bool   loading:      true
    property string errorMsg:     ""
    property var    sinks:        []
    property var    apps:         []
    property var    wp:           ({ sample_rate: 48000, buffer_size: 1024 })
    property var    mutedMap:     ({})
    property var    volumeMap:    ({})
    property bool   wpPending:    false
    property bool   wpRestarting: false
    property int    editRate:     0
    property int    editBuffer:   0

    readonly property var rateOptions:   [44100, 48000, 88200, 96000, 192000]
    readonly property var bufferOptions: [32, 64, 128, 256, 512, 1024, 2048]

    // ── Processos ─────────────────────────────────────────────────────────
    property string _buf: ""

    Process {
        id: fetchProc
        command: ["python3", root._script, "info"]
        running: false
        stdout: SplitParser { onRead: (l) => root._buf += l }
        onExited: (code) => {
            root.loading = false
            if (code !== 0) { root.errorMsg = "Script failed (exit " + code + ")"; return }
            try {
                const d = JSON.parse(root._buf)
                root.sinks = d.sinks ?? []
                if (!root._sliderActive) root.apps = d.apps ?? []
                root.wp = d.wp ?? { sample_rate: 48000, buffer_size: 1024 }
                root.editRate = root.wp.sample_rate
                root.editBuffer = root.wp.buffer_size
                root._buf = ""
            } catch(e) { root.errorMsg = "Parse error: " + e }
        }
    }

    property bool _sliderActive: false

    Process { id: volProc;   running: false; command: [] }
    Process { id: muteProc;  running: false; command: [] }

    Process {
        id: applyProc
        running: false; command: []
        onExited: (code) => {
            if (code === 0 && root.wpPending) {
                root.wpPending    = false
                root.wpRestarting = true
                restartProc.running = true
            }
        }
    }

    Process {
        id: restartProc
        command: ["systemctl", "--user", "restart", "wireplumber"]
        running: false
        onExited: () => {
            root.wpRestarting = false
            root._buf = ""; root.loading = true
            fetchProc.running = false
            Qt.callLater(() => fetchProc.running = true)
        }
    }

    function _apply(cfg) {
        if ("volume" in cfg && "app_index" in cfg) {
            volProc.command = ["pactl", "set-sink-input-volume", String(cfg.app_index), Math.round(cfg.volume * 100) + "%"]
            volProc.running = false; volProc.running = true
        } else if ("muted" in cfg && "app_index" in cfg) {
            muteProc.command = ["pactl", "set-sink-input-mute", String(cfg.app_index), cfg.muted ? "1" : "0"]
            muteProc.running = false; muteProc.running = true
        } else {
            applyProc.command = ["python3", root._script, "apply", JSON.stringify(cfg)]
            applyProc.running = false
            Qt.callLater(() => applyProc.running = true)
        }
    }

    property string _appsBuf: ""
    Process {
        id: fetchAppsProc
        command: ["python3", root._script, "apps"]
        running: false
        stdout: SplitParser { onRead: (l) => root._appsBuf += l }
        onExited: (code) => {
            if (code !== 0) { root._appsBuf = ""; return }
            try {
                const d = JSON.parse(root._appsBuf)
                if (!root._sliderActive) root.apps = d.apps ?? []
            } catch(e) {}
            root._appsBuf = ""
        }
    }

    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: {
            if (!root.loading && !root.wpRestarting) {
                fetchAppsProc.running = false
                Qt.callLater(() => fetchAppsProc.running = true)
            }
        }
    }

    Component.onCompleted: fetchProc.running = true

    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: {
            if (!root.loading && !root._sliderActive && !root.wpRestarting) {
                root._buf = ""
                fetchProc.running = false
                Qt.callLater(() => fetchProc.running = true)
            }
        }
    }

    // ── Loading / Error ───────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: root.loading
        text: root.wpRestarting ? "Restarting WirePlumber…" : "Loading audio info…"
        color: root.textSecondary; font.pixelSize: 13
    }
    Text {
        anchors.centerIn: parent
        visible: !root.loading && root.errorMsg !== ""
        text: "⚠  " + root.errorMsg
        color: root.errorColor; font.pixelSize: 13
        wrapMode: Text.WordWrap; width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Flickable {
        id: mainFlick
        anchors { fill: parent; margins: 28 }
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        visible: !root.loading && root.errorMsg === ""
        interactive: !root._sliderActive
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Qt.rgba(1,1,1,0.2) }
            background: Item {}
        }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 0

            // ── Output Device ─────────────────────────────────────────────
            SectionHeader { text: "OUTPUT DEVICE"; Layout.bottomMargin: 12 }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder
                implicitHeight: deviceCol.implicitHeight

                ColumnLayout {
                    id: deviceCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    Repeater {
                        model: root.sinks
                        delegate: SettingRow {
                            required property var modelData
                            required property int index
                            label:    modelData.description || modelData.name
                            sublabel: modelData.default ? "Default" : ""
                            isLast:   index === root.sinks.length - 1

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: modelData.default ? root.accent : "transparent"
                                border.width: 2
                                border.color: modelData.default ? root.accent : Qt.rgba(1,1,1,0.3)
                                Behavior on color { ColorAnimation { duration: 130 } }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 7; height: 7; radius: 4; color: "#fff"
                                    visible: modelData.default
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root._apply({ set_default_sink: modelData.name })
                                }
                            }
                        }
                    }
                }
            }

            // ── Volume por app ────────────────────────────────────────────
            SectionHeader { text: "APPLICATION VOLUME"; Layout.bottomMargin: 12 }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder
                implicitHeight: root.apps.length === 0 ? 64 : appsCol.implicitHeight

                Text {
                    anchors.centerIn: parent
                    visible: root.apps.length === 0
                    text: "No active audio streams"
                    color: root.textSecondary; font.pixelSize: 12
                }

                ColumnLayout {
                    id: appsCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0
                    visible: root.apps.length > 0

                    Repeater {
                        model: root.apps
                        delegate: Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 56

                            function capitalizeName(name) {
                                return name.replace(/\b\w/g, c => c.toUpperCase())
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 10

                                // ── Ícone do app ──────────────────────────
                                Rectangle {
                                    id: iconRect
                                    width: 28; height: 28; radius: 7
                                    property bool isMuted: (modelData.index in root.mutedMap)
                                        ? root.mutedMap[modelData.index]
                                        : modelData.muted
                                    color: isMuted ? Qt.rgba(1,0.27,0.23,0.2) : Qt.rgba(1,1,1,0.06)
                                    border.width: 1
                                    border.color: isMuted ? Qt.rgba(1,0.27,0.23,0.4) : root.cardBorder
                                    Behavior on color       { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Image {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        width: 18; height: 18
                                        source: modelData.icon ? "file://" + modelData.icon : ""
                                        visible: status === Image.Ready
                                        smooth: true; mipmap: true
                                        opacity: iconRect.isMuted ? 0.35 : 1.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !appIcon.visible
                                        text: "\ufa7d"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                                        color: root.textSecondary
                                        opacity: iconRect.isMuted ? 0.35 : 1.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const idx = modelData.index
                                            const current = (idx in root.mutedMap) ? root.mutedMap[idx] : modelData.muted
                                            const m = !current
                                            root.mutedMap = Object.assign({}, root.mutedMap, { [idx]: m })
                                            root._apply({ app_index: idx, muted: m })
                                        }
                                    }
                                }

                                // ── Nome do app ───────────────────────────
                                Text {
                                    Layout.preferredWidth: 100
                                    text: capitalizeName(modelData.name)
                                    property bool isMuted: (modelData.index in root.mutedMap)
                                        ? root.mutedMap[modelData.index]
                                        : modelData.muted
                                    color: isMuted ? root.textSecondary : root.textPrimary
                                    font.pixelSize: 12; elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                // ── Slider ────────────────────────────────
                                Item {
                                    id: sliderItem
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    property real maxVal: 1.5
                                    property real sliderValue: (root.volumeMap[modelData.index] !== undefined) ? root.volumeMap[modelData.index] : (modelData.volume || 0.0)

                                    Binding {
                                        target: sliderItem
                                        property: "sliderValue"
                                        value: (modelData.index in root.volumeMap)
                                            ? root.volumeMap[modelData.index]
                                            : modelData.volume
                                        when: !root._sliderActive
                                        restoreMode: Binding.RestoreNone
                                    }

                                    // track
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width; height: 4; radius: 2
                                        color: Qt.rgba(1,1,1,0.1)
                                        Rectangle {
                                            width: Math.min(1, sliderItem.sliderValue / sliderItem.maxVal) * parent.width
                                            height: parent.height; radius: 2
                                            color: sliderItem.sliderValue > 1.0 ? root.warningColor : root.accent
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    // thumb
                                    Rectangle {
                                        x: Math.min(1, sliderItem.sliderValue / sliderItem.maxVal) * (parent.width - width)
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14; height: 14; radius: 7
                                        color: "#ffffff"
                                        Behavior on x { enabled: !dragMa.drag.active; NumberAnimation { duration: 80 } }
                                    }

                                    MouseArea {
                                        id: dragMa
                                        anchors.fill: parent
                                        drag.target: null
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: (mouse) => {
                                            root._sliderActive = true
                                            const ratio = Math.max(0, Math.min(1, mouse.x / sliderItem.width))
                                            sliderItem.sliderValue = ratio * sliderItem.maxVal
                                            root._apply({ app_index: modelData.index, volume: sliderItem.sliderValue })
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (!pressed) return
                                            const ratio = Math.max(0, Math.min(1, mouse.x / sliderItem.width))
                                            sliderItem.sliderValue = ratio * sliderItem.maxVal
                                            root._apply({ app_index: modelData.index, volume: sliderItem.sliderValue })
                                        }
                                        onReleased: {
                                            const map = Object.assign({}, root.volumeMap)
                                            map[modelData.index] = sliderItem.sliderValue
                                            root.volumeMap = map
                                            root._sliderActive = false
                                        }
                                    }
                                }

                                // ── Percentual ────────────────────────────
                                Text {
                                    Layout.preferredWidth: 36
                                    text: Math.round(sliderItem.sliderValue * 100) + "%"
                                    color: sliderItem.sliderValue > 1.0 ? root.warningColor : root.textSecondary
                                    font.pixelSize: 11; horizontalAlignment: Text.AlignRight
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            Rectangle {
                                visible: index < root.apps.length - 1
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: root.cardBorder
                            }
                        }
                    }
                }
            }

            // ── WirePlumber ───────────────────────────────────────────────
            SectionHeader { text: "PIPEWIRE / WIREPLUMBER"; Layout.bottomMargin: 12 }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder
                implicitHeight: wpCol.implicitHeight

                ColumnLayout {
                    id: wpCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: "Sample Rate"
                        sublabel: "Current: " + root.wp.sample_rate + " Hz"
                        isLast: false
                        SelectButton {
                            implicitWidth: 130
                            label: root.editRate + " Hz"
                            options: root.rateOptions.map(r => r + " Hz")
                            selectedIndex: Math.max(0, root.rateOptions.indexOf(root.editRate))
                            popupDirection: "up"
                            onSelected: (i) => {
                                root.editRate = root.rateOptions[i]
                                root.wpPending = root.editRate !== root.wp.sample_rate ||
                                                 root.editBuffer !== root.wp.buffer_size
                            }
                        }
                    }

                    SettingRow {
                        label: "Buffer Size"
                        sublabel: "Current: " + root.wp.buffer_size + " samples  (~" +
                                  Math.round(root.wp.buffer_size / root.wp.sample_rate * 1000) + " ms)"
                        isLast: false
                        SelectButton {
                            implicitWidth: 130
                            label: root.editBuffer + " samples"
                            options: root.bufferOptions.map(b => b + " samples")
                            selectedIndex: Math.max(0, root.bufferOptions.indexOf(root.editBuffer))
                            popupDirection: "up"
                            onSelected: (i) => {
                                root.editBuffer = root.bufferOptions[i]
                                root.wpPending = root.editRate !== root.wp.sample_rate ||
                                                 root.editBuffer !== root.wp.buffer_size
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true; implicitHeight: 52

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            text: root.wpPending ? "⚠  Requires WirePlumber restart" : "Changes will restart WirePlumber"
                            font.pixelSize: 11
                            color: root.wpPending ? root.warningColor : root.textSecondary
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Rectangle {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                            implicitWidth: applyLbl.implicitWidth + 28; implicitHeight: 32; radius: 8
                            color: root.wpPending
                                ? (applyMa.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent)
                                : Qt.rgba(1,1,1,0.06)
                            border.width: root.wpPending ? 0 : 1; border.color: root.cardBorder
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                id: applyLbl; anchors.centerIn: parent; text: "Apply"
                                font.pixelSize: 12; font.weight: Font.Medium
                                color: root.wpPending ? "#ffffff" : root.textSecondary
                            }
                            MouseArea {
                                id: applyMa; anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor; enabled: root.wpPending
                                onClicked: root._apply({ sample_rate: root.editRate, buffer_size: root.editBuffer })
                            }
                        }
                    }
                }
            }

            Item { implicitHeight: 8 }
        }
    }

    // ── Inline Components ─────────────────────────────────────────────────

    component SectionHeader: Text {
        required property string text
        font.pixelSize: 10; font.weight: Font.Medium
        font.letterSpacing: 1.2; color: root.textSecondary
    }

    component SettingRow: RowLayout {
        id: sr
        required property string label
        property  string sublabel: ""
        property  bool   isLast:  false
        default property alias control: slot.data
        Layout.fillWidth: true
        spacing: 12

        Item {
            Layout.fillWidth: true
            implicitHeight: sr.sublabel !== "" ? 56 : 44
            ColumnLayout {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 16
                }
                spacing: 2
                Text { text: sr.label; color: root.textPrimary; font.pixelSize: 13 }
                Text {
                    visible: sr.sublabel !== ""; text: sr.sublabel
                    color: root.textSecondary; font.pixelSize: 11
                }
            }
            Rectangle {
                visible: !sr.isLast
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                height: 1; color: root.cardBorder
            }
        }

        Item {
            id: slot
            implicitWidth:  children.length > 0 ? children[0].implicitWidth  : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            Layout.rightMargin: 16
            Layout.alignment: Qt.AlignVCenter
        }
    }

    component SelectButton: Item {
        id: sel
        required property string label
        required property var    options
        required property int    selectedIndex
        property string popupDirection: "down"
        signal selected(int index)
        implicitHeight: 34

        readonly property int maxVisible: 6
        readonly property int itemH:      36
        readonly property int popupPad:   6
        readonly property int listH: Math.min(sel.options.length, sel.maxVisible) * sel.itemH + popupPad * 2

        Rectangle {
            anchors.fill: parent; radius: 8
            color: btn.containsMouse ? Qt.rgba(1,1,1,0.08) : root.cardBg
            border.width: 1
            border.color: dd.visible ? root.accent : root.cardBorder
            Behavior on color        { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                spacing: 6
                Text {
                    Layout.fillWidth: true; text: sel.label
                    color: root.textPrimary; font.pixelSize: 12; elide: Text.ElideRight
                }
                Text { text: dd.visible ? "⌃" : "⌄"; color: root.textSecondary; font.pixelSize: 11 }
            }
            MouseArea {
                id: btn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: dd.visible ? dd.close() : dd.open()
            }
        }

        Popup {
            id: dd
            y: sel.popupDirection === "up" ? -(sel.listH + 4) : sel.height + 4
            width: Math.max(sel.width, 160); height: sel.listH; padding: sel.popupPad
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            background: Rectangle {
                radius: 10; color: root.popupBg
                border.width: 1; border.color: root.cardBorder
            }
            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130; easing.type: Easing.OutCubic }
            }
            exit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
            }
            contentItem: ListView {
                id: lv; clip: true; model: sel.options; spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: sel.options.length > sel.maxVisible ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Qt.rgba(1,1,1,0.25) }
                    background: Rectangle { color: "transparent" }
                }
                onVisibleChanged: if (visible && sel.selectedIndex >= 0) positionViewAtIndex(sel.selectedIndex, ListView.Contain)
                delegate: Rectangle {
                    readonly property bool active: sel.selectedIndex === index
                    width: lv.width; height: sel.itemH; radius: 7
                    color: active ? Qt.rgba(10/255,132/255,1,0.18) : ra.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        Text {
                            Layout.fillWidth: true; text: modelData
                            color: active ? root.accent : root.textPrimary
                            font.pixelSize: 13; font.weight: active ? Font.Medium : Font.Normal
                        }
                        Text { visible: active; text: "✓"; color: root.accent; font.pixelSize: 12 }
                    }
                    MouseArea {
                        id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { sel.selected(index); dd.close() }
                    }
                }
            }
        }
    }
}
