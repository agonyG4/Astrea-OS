import QtQuick
import Quickshell
import Quickshell.Io
import "../../../.."
import "../../../../../AstreaI18n" as AstreaI18n

Item {
    id: root

    height: 36
    width: clockButton.width
    property var popupHost: null

    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + ""
    readonly property string regionScript: astreaRoot + "/Core/bridge/system/region.py"
    readonly property string regionSettingsPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/system/settings.json"
    readonly property var _countryTimeDefaults: ({
        BR: "24h",
        US: "12h",
        PT: "24h",
        GB: "24h",
        FR: "24h",
        ES: "24h",
        DE: "24h",
        IT: "24h",
        CA: "12h",
        JP: "24h",
        AR: "24h",
        CL: "24h",
        UY: "24h"
    })
    property string timeFormat: "24h"
    property string _regionBuf: ""

    readonly property var _days: [
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.day.sun"]) || "Sun",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.day.mon"]) || "Mon",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.day.tue"]) || "Tue",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.day.wed"]) || "Wed",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.day.thu"]) || "Thu",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.day.fri"]) || "Fri",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.day.sat"]) || "Sat"
    ]
    readonly property var _months: [
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.jan"]) || "Jan",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.feb"]) || "Feb",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.mar"]) || "Mar",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.apr"]) || "Apr",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.may"]) || "May",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.jun"]) || "Jun",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.jul"]) || "Jul",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.aug"]) || "Aug",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.sep"]) || "Sep",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.oct"]) || "Oct",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.nov"]) || "Nov",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.clock.month.dec"]) || "Dec"
    ]

    function _resolveTimeFormat(region) {
        const selected = String((region && region.time_format) || "system").toLowerCase()
        if (selected === "12h" || selected === "24h")
            return selected
        const country = String((region && region.country_code) || "BR").toUpperCase()
        return _countryTimeDefaults[country] || "24h"
    }

    function _applyRegionPayload(payload) {
        const nextFormat = (payload && (payload.effective_time_format || _resolveTimeFormat((payload.config || {}).region))) || "24h"
        if (nextFormat === "12h" || nextFormat === "24h")
            root.timeFormat = nextFormat
        root._update()
    }

    function _reloadRegionSettings() {
        if (regionProc.running)
            return
        root._regionBuf = ""
        regionProc.command = ["python3", root.regionScript, "get"]
        regionProc.running = true
    }

    function _formatTime(now) {
        const h = now.getHours()
        const m = now.getMinutes().toString().padStart(2, "0")
        if (root.timeFormat === "12h")
            return `${(h % 12 || 12).toString().padStart(2, "0")}:${m} ${h < 12 ? "AM" : "PM"}`
        return `${h.toString().padStart(2, "0")}:${m}`
    }

    function _update() {
        const now = new Date()
        _clockText.text = _formatTime(now)
        _dateText.text  = `${_days[now.getDay()]} ${_months[now.getMonth()]} ${now.getDate()}`
        _scheduleNextMinute(now)
    }

    function _scheduleNextMinute(now) {
        const next = new Date(now.getTime())
        next.setSeconds(0)
        next.setMilliseconds(0)
        next.setMinutes(next.getMinutes() + 1)
        clockTimer.interval = Math.max(250, next.getTime() - now.getTime() + 20)
        clockTimer.restart()
    }

    function _toggleNotifications() {
        clockButton.togglePopup()
    }

    Timer {
        id: clockTimer
        repeat: false
        onTriggered: root._update()
    }

    Timer {
        id: regionFileReloadDebounce
        interval: 120
        repeat: false
        onTriggered: regionFile.reload()
    }

    Process {
        id: regionProc
        running: false
        command: []
        stdout: SplitParser {
            onRead: data => root._regionBuf += data
        }
        onExited: code => {
            if (code === 0) {
                try {
                    root._applyRegionPayload(JSON.parse(root._regionBuf || "{}"))
                } catch (error) {
                }
            }
            root._regionBuf = ""
        }
    }

    FileView {
        id: regionFile
        path: root.regionSettingsPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: regionFileReloadDebounce.restart()
        onLoaded: {
            try {
                root._applyRegionPayload({ config: JSON.parse(text() || "{}") })
            } catch (error) {
            }
        }
    }

    Connections {
        target: AstreaI18n.I18n
        function onMessagesChanged() {
            root._update()
        }
    }

    Component.onCompleted: {
        root._reloadRegionSettings()
        root._update()
    }

    TopbarIndicator {
        id: clockButton
        anchors.centerIn: parent
        popupHost: root.popupHost
        horizontalPadding: Theme.spacingTiny
        spacing: 0

        Item {
            width:  _dateText.implicitWidth + 8
            height: clockButton.height
            Text {
                id: _dateText
                anchors.fill: parent
                color: Theme.shellTextSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font {
                    family: Theme.fontFamilyDisplay
                    pixelSize: Theme.fontSizeSmall
                    weight: Font.Medium
                    letterSpacing: 0.3
                }
                renderType: Text.NativeRendering
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: _dateText; property: "opacity"; to: 0; duration: Theme.animationQuick }
                        NumberAnimation { target: _dateText; property: "opacity"; to: 1; duration: Theme.animationQuick }
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 16
            color: Theme.shellSeparator
        }

        Item {
            width:  _clockText.implicitWidth + 16
            height: clockButton.height
            Text {
                id: _clockText
                anchors.fill: parent
                color: Theme.shellTextActive
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font {
                    family: Theme.fontFamilyDisplay
                    pixelSize: Theme.fontSizeTitle
                    weight: Font.Medium
                    letterSpacing: 0.35
                }
                renderType: Text.NativeRendering
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: _clockText; property: "opacity"; to: 0; duration: Theme.animationFast; easing.type: Easing.InQuad }
                        NumberAnimation { target: _clockText; property: "opacity"; to: 1; duration: Theme.animationNormal; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }
}
