import QtQuick
import "../../../.."
import "../../../../../AstreaI18n" as AstreaI18n

Item {
    id: root

    height: 36
    width:  _row.implicitWidth

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

    function _update() {
        const now = new Date()
        const h   = now.getHours()
        _clockText.text = `${(h % 12 || 12).toString().padStart(2,"0")}:${now.getMinutes().toString().padStart(2,"0")} ${h < 12 ? "AM" : "PM"}`
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

    Timer {
        id: clockTimer
        repeat: false
        onTriggered: root._update()
    }

    Connections {
        target: AstreaI18n.I18n
        function onMessagesChanged() {
            root._update()
        }
    }

    Component.onCompleted: root._update()

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 0

        Item {
            width:  _dateText.implicitWidth + 16
            height: 36
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
            width:  _clockText.implicitWidth + 20
            height: 36
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
