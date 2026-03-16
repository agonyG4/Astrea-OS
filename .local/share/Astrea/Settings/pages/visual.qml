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
    readonly property color errorColor:    "#ff453a"
    readonly property color popupBg:       Qt.rgba(0.13, 0.13, 0.14, 0.97)

    // ── Paths ─────────────────────────────────────────────────────────────
    readonly property string scriptPath:  Quickshell.env("HOME") + "/.local/share/Astrea/Settings/components/visual/scripts/get-monitor-info.py"
    readonly property string confPath:    Quickshell.env("HOME") + "/.local/share/Astrea/Settings/components/visual/monitor-settings.conf"
    readonly property string applyScript: Quickshell.env("HOME") + "/.local/share/Astrea/Settings/components/visual/scripts/monitor_apply.sh"

    // ── Monitor state ─────────────────────────────────────────────────────
    property var    monitors:      []
    property int    activeMonitor: 0
    property string errorMessage:  ""
    property bool   loading:       true

    readonly property var mon: monitors.length > 0 ? monitors[activeMonitor] : null

    // ── Settings state ────────────────────────────────────────────────────
    property int  selectedResolution: 0
    property int  selectedHz:         0
    property int  selectedBitdepth:   1
    property int  selectedScale:      2
    property bool vrrEnabled:         false
    property bool showAllResolutions: false
    property bool savedVisible:       false

    // ── Computed ──────────────────────────────────────────────────────────
    readonly property var currentHzList: {
        if (!mon) return []
        return mon.refreshRates[mon.resolutions[selectedResolution]] ?? []
    }

    readonly property var defaultResolutionIndices: {
        if (!mon || mon.resolutions.length === 0) return []
        const resols    = mon.resolutions
        const nativeIdx = resols.length - 1
        const nativeH   = parseInt(resols[nativeIdx].split("x")[1])
        const knownH    = [720, 900, 1080, 1440, 2160]
        const set = new Set([nativeIdx, selectedResolution])
        knownH.filter(h => h < nativeH)
              .slice(-2)
              .forEach(h => {
                  let best = -1
                  for (let i = 0; i < resols.length; i++) {
                      if (parseInt(resols[i].split("x")[1]) !== h) continue
                      if (best < 0 || parseInt(resols[i].split("x")[0]) > parseInt(resols[best].split("x")[0]))
                          best = i
                  }
                  if (best >= 0) set.add(best)
              })
        return Array.from(set).sort((a, b) => b - a)
    }

    onSelectedResolutionChanged: selectedHz = 0

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
            } catch (e) {
                root.errorMessage = "JSON parse error: " + e
            }
        }
    }

    Process {
        id: saveProc
        running: false
        command: []
        onExited: (code, _) => { if (code === 0) applyProc.running = true }
    }

    Process {
        id: applyProc
        command: ["bash", root.applyScript]
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

    // ── Funções ───────────────────────────────────────────────────────────
    function _applyCurrentValues() {
        if (!mon) return
        const cur = mon.current
        const ri = mon.resolutions.indexOf(cur.resolution)
        selectedResolution = ri >= 0 ? ri : 0
        const hzList = mon.refreshRates[cur.resolution] ?? []
        selectedHz = Math.max(0, hzList.indexOf(cur.refreshRate))
        const bi = mon.bitdepths.indexOf(cur.bitdepth)
        selectedBitdepth = bi >= 0 ? bi : 1
        const si = mon.scales.indexOf(cur.scale)
        selectedScale = si >= 0 ? si : 2
        vrrEnabled         = cur.vrr ?? false
        showAllResolutions = false
    }

    function saveSettings() {
        if (!mon) return
        const res   = mon.resolutions[selectedResolution]
        const hz    = currentHzList[selectedHz]
        const bpc   = mon.bitdepths[selectedBitdepth]
        const scale = mon.scales[selectedScale]
        const safe  = (s) => String(s).replace(/'/g, "'\\''")
        const content = [
            "monitor="     + mon.name,
            "resolution="  + res,
            "refreshrate=" + hz,
            "bitdepth="    + bpc,
            "scale="       + scale,
            "vrr="         + (vrrEnabled ? 1 : 0)
        ].join("\n")
        saveProc.command = [
            "bash", "-c",
            `mkdir -p "$(dirname '${safe(confPath)}')" && ` +
            `printf '%s' '${safe(content)}' > '${safe(confPath)}'`
        ]
        saveProc.running = true
        savedVisible     = true
        savedTimer.restart()
    }

    function _monitorLabel(m) {
        const words = (m.description || "").split(" ")
        return m.name + (words[0] ? " — " + words.slice(0, 2).join(" ") : "")
    }

    Component.onCompleted: fetchProc.running = true

    // ── Loading ───────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: root.loading
        text: "Loading monitor info…"
        color: root.textSecondary
        font.pixelSize: 13
    }

    // ── Erro ──────────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: !root.loading && root.errorMessage !== ""
        text: "⚠  " + root.errorMessage
        color: root.errorColor
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Layout principal ──────────────────────────────────────────────────
    ScrollView {
        anchors { fill: parent; margins: 28 }
        contentWidth: availableWidth
        clip: true
        visible: !root.loading && root.errorMessage === "" && root.mon !== null

        ColumnLayout {
            width: parent.width
            spacing: 0

            // ── Seletor de monitor ────────────────────────────────────────
            ColumnLayout {
                visible: root.monitors.length > 1
                Layout.fillWidth: true
                spacing: 6
                Layout.bottomMargin: 24

                SectionHeader { text: "MONITOR" }
                SelectButton {
                    Layout.fillWidth: true
                    label: root.mon ? _monitorLabel(root.mon) : ""
                    options: root.monitors.map(m => _monitorLabel(m))
                    selectedIndex: root.activeMonitor
                    onSelected: (i) => { root.activeMonitor = i; root._applyCurrentValues() }
                }
            }

            // ── Resolução ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Layout.bottomMargin: 24

                SectionHeader {
                    text: "RESOLUTION"
                    Layout.bottomMargin: 8
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: {
                            if (!root.mon) return []
                            if (root.showAllResolutions)
                                return Array.from({ length: root.mon.resolutions.length }, (_, i) => i).reverse()
                            return root.defaultResolutionIndices
                        }

                        delegate: Rectangle {
                            readonly property int    realIndex: modelData
                            readonly property bool   active:    realIndex === root.selectedResolution
                            readonly property bool   isNative:  realIndex === (root.mon ? root.mon.resolutions.length - 1 : -1)
                            readonly property string resText:   root.mon ? root.mon.resolutions[realIndex].replace("x", "×") : ""

                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 8
                            color: active
                                ? Qt.rgba(10/255, 132/255, 1, 0.12)
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
                                    font.pixelSize: 13
                                    font.weight: active ? Font.Medium : Font.Normal
                                    Behavior on color { ColorAnimation { duration: 110 } }
                                }

                                Rectangle {
                                    visible: isNative
                                    implicitWidth:  defaultLbl.implicitWidth + 10
                                    implicitHeight: 16
                                    radius: 4
                                    color: active
                                        ? Qt.rgba(10/255, 132/255, 1, 0.25)
                                        : Qt.rgba(1, 1, 1, 0.08)
                                    Text {
                                        id: defaultLbl
                                        anchors.centerIn: parent
                                        text: "Default"
                                        color: active ? root.accent : root.textSecondary
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        font.letterSpacing: 0.3
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    visible: active
                                    text: "✓"
                                    color: root.accent
                                    font.pixelSize: 12
                                }
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
                    color: toggleResArea.containsMouse
                        ? Qt.lighter(root.accent, 1.2)
                        : root.textSecondary
                    font.pixelSize: 11
                    font.weight: Font.Medium
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

            // ── Card de configurações ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12
                color: root.cardBg
                border.width: 1
                border.color: root.cardBorder
                implicitHeight: settingsCol.implicitHeight

                ColumnLayout {
                    id: settingsCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: "Refresh rate"
                        isLast: false
                        SelectButton {
                            implicitWidth: 130
                            label: root.currentHzList.length > 0
                                ? root.currentHzList[root.selectedHz] + " Hz" : "—"
                            options: root.currentHzList.map(hz => hz + " Hz")
                            selectedIndex: root.selectedHz
                            onSelected: (i) => root.selectedHz = i
                        }
                    }

                    SettingRow {
                        label: "Color depth"
                        isLast: false
                        SelectButton {
                            implicitWidth: 130
                            label: root.mon ? root.mon.bitdepths[root.selectedBitdepth] + " bpc" : "—"
                            options: root.mon ? root.mon.bitdepths.map(b => b + " bpc") : []
                            selectedIndex: root.selectedBitdepth
                            onSelected: (i) => root.selectedBitdepth = i
                        }
                    }

                    SettingRow {
                        label: "Variable Refresh Rate"
                        sublabel: "VRR / FreeSync / G-Sync"
                        isLast: false
                        Rectangle {
                            implicitWidth:  56
                            implicitHeight: 30
                            radius: 15
                            color: root.vrrEnabled ? root.accent : Qt.rgba(1, 1, 1, 0.15)
                            Behavior on color { ColorAnimation { duration: 220 } }
                            Rectangle {
                                width:  24
                                height: 24
                                radius: 12
                                color:  "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.vrrEnabled ? parent.width - width - 3 : 3
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(0, 0, 0, 0.18)
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.vrrEnabled = !root.vrrEnabled
                            }
                        }
                    }

                    SettingRow {
                        label: "Display scale"
                        isLast: true
                        SelectButton {
                            implicitWidth: 130
                            label: root.mon ? root.mon.scales[root.selectedScale] + "×" : "—"
                            options: root.mon ? root.mon.scales.map(s => s + "×") : []
                            selectedIndex: root.selectedScale
                            onSelected: (i) => root.selectedScale = i
                        }
                    }
                }
            }

            // ── Barra de aplicar ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                spacing: 12

                Item { Layout.fillWidth: true }

                Text {
                    text: "✓ Applied"
                    color: root.accent
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    opacity: root.savedVisible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Rectangle {
                    implicitWidth:  applyLbl.implicitWidth + 32
                    implicitHeight: 34
                    radius: 8
                    color: applyArea.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: applyLbl
                        anchors.centerIn: parent
                        text: "Apply"
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.Medium
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

        } // ColumnLayout
    } // ScrollView

    // ═════════════════════════════════════════════════════════════════════
    // ── Inline Components ─────────────────────────────────────────────────

    component SectionHeader: Text {
        required property string text
        font.pixelSize:     10
        font.weight:        Font.Medium
        font.letterSpacing: 1.2
        color: root.textSecondary
    }

    component SettingRow: RowLayout {
        id: settingRow
        required property string label
        property string sublabel: ""
        property bool   isLast:  false
        default property alias control: controlSlot.data

        Layout.fillWidth: true
        spacing: 12

        Item {
            Layout.fillWidth: true
            implicitHeight: settingRow.sublabel !== "" ? 56 : 44

            ColumnLayout {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 16
                }
                spacing: 2
                Text {
                    text: settingRow.label
                    color: root.textPrimary
                    font.pixelSize: 13
                }
                Text {
                    visible: settingRow.sublabel !== ""
                    text: settingRow.sublabel
                    color: root.textSecondary
                    font.pixelSize: 11
                }
            }

            Rectangle {
                visible: !settingRow.isLast
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                height: 1
                color: root.cardBorder
            }
        }

        Item {
            id: controlSlot
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
        signal selected(int index)

        implicitHeight: 34

        readonly property int maxVisible: 5
        readonly property int itemH:      36
        readonly property int popupPad:   6
        readonly property int listH:
            Math.min(sel.options.length, sel.maxVisible) * sel.itemH + popupPad * 2

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : root.cardBg
            border.width: 1
            border.color: dropdown.visible ? root.accent : root.cardBorder
            Behavior on color        { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: sel.label
                    color: root.textPrimary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    text: dropdown.visible ? "⌃" : "⌄"
                    color: root.textSecondary
                    font.pixelSize: 11
                }
            }

            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dropdown.visible ? dropdown.close() : dropdown.open()
            }
        }

        Popup {
            id: dropdown
            y: sel.height + 4
            width: Math.max(sel.width, 160)
            height: sel.listH
            padding: sel.popupPad
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                radius: 10
                color: root.popupBg
                border.width: 1
                border.color: root.cardBorder
            }

            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: sel.height; to: sel.height + 4; duration: 130; easing.type: Easing.OutCubic }
            }
            exit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
            }

            contentItem: ListView {
                id: listView
                clip: true
                model: sel.options
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: sel.options.length > sel.maxVisible
                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                    background: Rectangle { color: "transparent" }
                }

                onVisibleChanged: {
                    if (visible && sel.selectedIndex >= 0)
                        positionViewAtIndex(sel.selectedIndex, ListView.Contain)
                }

                delegate: Rectangle {
                    readonly property bool active: sel.selectedIndex === index
                    width: listView.width
                    height: sel.itemH
                    radius: 7
                    color: active
                        ? Qt.rgba(10/255, 132/255, 1, 0.18)
                        : rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: active ? root.accent : root.textPrimary
                            font.pixelSize: 13
                            font.weight: active ? Font.Medium : Font.Normal
                        }
                        Text {
                            visible: active
                            text: "✓"
                            color: root.accent
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { sel.selected(index); dropdown.close() }
                    }
                }
            }
        }
    }
}
