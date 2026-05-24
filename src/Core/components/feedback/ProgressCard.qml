import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property string title: ""
    property string detail: ""
    property string destination: ""
    property real progress: 0
    property int percent: Math.round(Math.max(0, Math.min(1, progress)) * 100)
    property int completedItems: 0
    property int totalItems: 0
    property string remainingText: ""
    property bool indeterminate: totalItems <= 0 && percent <= 0 && !failed
    property bool failed: false
    property color panelColor: "#1e1e20"
    property color borderColor: "#3a3a3c"
    property color primaryTextColor: "#f2f2f7"
    property color secondaryTextColor: "#8e8e93"
    property color trackColor: "#2c2c2e"
    property color fillColor: "#f2f2f7"
    property color errorColor: "#ff8b8b"

    width: 320
    height: 82
    radius: 8
    color: panelColor
    border.width: 1
    border.color: borderColor

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 7

        RowLayout {
            width: parent.width
            height: 16
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: card.title
                color: card.failed ? card.errorColor : card.primaryTextColor
                font { pixelSize: 12; weight: Font.DemiBold }
                elide: Text.ElideRight
            }

            Text {
                text: card.indeterminate ? "" : card.percent + "%"
                color: card.secondaryTextColor
                font.pixelSize: 11
                visible: !card.failed
            }
        }

        Text {
            width: parent.width
            height: 14
            text: card.destination !== "" ? card.detail + " -> " + card.destination : card.detail
            color: card.secondaryTextColor
            font.pixelSize: 11
            elide: Text.ElideMiddle
            visible: text !== ""
        }

        RowLayout {
            width: parent.width
            height: 16
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 5
                radius: 3
                color: card.trackColor
                clip: true

                Rectangle {
                    id: progressFill

                    anchors { top: parent.top; bottom: parent.bottom }
                    x: card.indeterminate ? -width : 0
                    width: card.indeterminate ? Math.max(42, parent.width * 0.34) : parent.width * Math.max(0, Math.min(1, card.progress))
                    radius: 3
                    color: card.failed ? card.errorColor : card.fillColor

                    SequentialAnimation on x {
                        running: card.visible && card.indeterminate
                        loops: Animation.Infinite
                        NumberAnimation { from: -progressFill.width; to: progressFill.parent.width; duration: 1100; easing.type: Easing.InOutQuad }
                    }

                    Behavior on width {
                        enabled: !card.indeterminate
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 96
                text: card.failed ? "Falhou" : (card.remainingText !== "" ? card.remainingText : (card.totalItems > 0 ? (card.completedItems + " / " + card.totalItems) : (card.completedItems > 0 ? (card.completedItems + " itens") : "Preparando")))
                color: card.secondaryTextColor
                font.pixelSize: 11
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
