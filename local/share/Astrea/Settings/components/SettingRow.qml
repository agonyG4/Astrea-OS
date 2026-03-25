import QtQuick
import QtQuick.Layouts

RowLayout {
    id: sr
    property string label: ""
    property string sublabel: ""
    property bool   isLast:  false
    
    // Theme colors
    property color textPrimary:   "#ffffff"
    property color textSecondary: "#98989f"
    property color cardBorder:    Qt.rgba(1, 1, 1, 0.08)

    default property alias control: slot.data
    Layout.fillWidth: true; spacing: 12

    Item {
        Layout.fillWidth: true
        implicitHeight: sr.sublabel !== "" ? 56 : 46
        ColumnLayout {
            anchors { 
                left: parent.left; right: parent.right; 
                verticalCenter: parent.verticalCenter; leftMargin: 16 
            }
            spacing: 2
            Text { text: sr.label; color: sr.textPrimary; font.pixelSize: 13; font.weight: Font.Normal }
            Text {
                visible: sr.sublabel !== ""; text: sr.sublabel
                color: sr.textSecondary; font.pixelSize: 11
            }
        }
        Rectangle {
            visible: !sr.isLast
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
            height: 1; color: sr.cardBorder
        }
    }
    Item {
        id: slot
        implicitWidth:  children.length > 0 ? children[0].implicitWidth  : 0
        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        Layout.rightMargin: 16; Layout.alignment: Qt.AlignVCenter
    }
}
