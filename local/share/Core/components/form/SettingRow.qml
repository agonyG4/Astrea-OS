import QtQuick
import QtQuick.Layouts
import ".." as Components

Item {
    id: sr
    property string label: ""
    property string sublabel: ""
    property bool   isLast:  false
    
    // Theme colors
    property color textPrimary: Components.Theme.textPrimary
    property color textSecondary: Components.Theme.textSecondary
    property color cardBorder: Components.Theme.cardBorder
    property color rowHoverBg:    Qt.rgba(1, 1, 1, 0.03)

    default property alias control: slot.data
    implicitWidth: parent ? parent.width : 200
    implicitHeight: sr.sublabel !== "" ? 64 : 52

    // Interactive subtle hover background
    Rectangle {
        id: bgHighlight
        anchors { fill: parent; leftMargin: 4; rightMargin: 4; topMargin: 2; bottomMargin: 2 }
        radius: 10
        color: rowArea.containsMouse ? sr.rowHoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuart } }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            
            Text { 
                text: sr.label; 
                color: sr.textPrimary; 
                font.family: Components.Theme.fontFamily
                font.pixelSize: Components.Theme.fontSizeLarge; 
                font.weight: Components.Theme.fontWeightMedium 
                // Subtle scale or translation could theoretically be added here
            }
            Text {
                visible: sr.sublabel !== ""; 
                text: sr.sublabel
                color: sr.textSecondary; 
                font.family: Components.Theme.fontFamily
                font.pixelSize: Components.Theme.fontSizeSmall; 
                font.weight: Components.Theme.fontWeightNormal
            }
        }

        Item {
            id: slot
            implicitWidth:  children.length > 0 ? children[0].implicitWidth  : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            scale: rowArea.pressed ? 0.98 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }

    Rectangle {
        visible: !sr.isLast
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 18 }
        height: 1; 
        color: sr.cardBorder
    }

    signal rightClicked()

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                sr.rightClicked()
            } else {
                mouse.accepted = false
            }
        }
        onReleased: (mouse) => {
            if (mouse.button !== Qt.RightButton) {
                mouse.accepted = false
            }
        }
    }
}
