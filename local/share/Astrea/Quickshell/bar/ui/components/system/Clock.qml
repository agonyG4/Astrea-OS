// Clock.qml — componente autônomo (timer interno, sem dependência externa)
import QtQuick
import "../../.."

Item {
    id: root

    // ── Dimensões ─────────────────────────────────────────────────
    height: 36
    width:  _row.implicitWidth

    // ── Dados internos ────────────────────────────────────────────
    readonly property var _days:   ["Dom","Seg","Ter","Qua","Qui","Sex","Sáb"]
    readonly property var _months: ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"]

    function _update() {
        const now = new Date()
        const h   = now.getHours()
        _clockText.text = `${(h % 12 || 12).toString().padStart(2,"0")}:${now.getMinutes().toString().padStart(2,"0")} ${h < 12 ? "AM" : "PM"}`
        _dateText.text  = `${_days[now.getDay()]} ${_months[now.getMonth()]} ${now.getDate()}`
    }

    Timer {
        interval:         1000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered:      root._update()
    }

    // ── Layout ────────────────────────────────────────────────────
    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 0

        // Data
        Item {
            width:  _dateText.implicitWidth + 16
            height: 36
            Text {
                id: _dateText
                anchors.fill: parent
                color: Theme.textSecondary
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
                        NumberAnimation { target: _dateText; property: "opacity"; to: 0; duration: 120 }
                        NumberAnimation { target: _dateText; property: "opacity"; to: 1; duration: 120 }
                    }
                }
            }
        }

        // Divisor
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 16
            color: Theme.separator
        }

        // Hora
        Item {
            width:  _clockText.implicitWidth + 20
            height: 36
            Text {
                id: _clockText
                anchors.fill: parent
                color: Theme.textActive
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
                        NumberAnimation { target: _clockText; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InQuad }
                        NumberAnimation { target: _clockText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }
}
