import QtQuick
import QtQuick.Layouts
import ".." as Components

Item {
    id: rowRoot
    Layout.fillWidth: true
    implicitHeight: 52

    property string iconText: ""
    property color iconColor: Components.Theme.textSecondary
    property real iconOpacity: 0.6
    
    property string label: ""
    property string sublabel: ""
    property color sublabelColor: Components.Theme.textSecondary
    property real sublabelOpacity: 0.5
    
    property bool isLast: false
    property bool showChevron: false
    property bool interactive: true

    default property alias control: slot.data
    signal clicked()

    // Hover background
    Rectangle {
        anchors.fill: parent
        color: rowArea.containsMouse && rowRoot.interactive ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }
        radius: Components.Theme.cornerRadiusSmall
        anchors.margins: Components.Theme.spacingTiny
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Components.Theme.spacingLarge
        anchors.rightMargin: Components.Theme.spacingLarge
        spacing: Components.Theme.spacingMedium

        // Optional Left Icon
        Text {
            visible: rowRoot.iconText !== ""
            text: rowRoot.iconText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: rowRoot.iconColor
            opacity: rowRoot.iconOpacity
        }

        // Label
        Text {
            text: rowRoot.label
            color: Components.Theme.textPrimary
            font.pixelSize: 14
            Layout.fillWidth: true
            font.family: Components.Theme.fontFamily
        }

        // Sublabel
        Text {
            visible: rowRoot.sublabel !== ""
            text: rowRoot.sublabel
            color: rowRoot.sublabelColor
            font.pixelSize: 13
            opacity: rowRoot.sublabelOpacity
            font.family: Components.Theme.fontFamily
        }
        
        // Slot for custom controls (like BusyIndicator, Switches, etc)
        Item {
            id: slot
            implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            Layout.alignment: Qt.AlignVCenter
        }
        
        // Optional Chevron
        Text {
            visible: rowRoot.showChevron
            text: "󰅂" // Nerd Font chevron right
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: Components.Theme.textSecondary
            opacity: Components.Theme.opacityDisabled
        }
    }
    
    // Bottom separator
    Rectangle {
        visible: !rowRoot.isLast
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: rowRoot.iconText !== "" ? 44 : Components.Theme.spacingLarge
        height: 1
        color: Components.Theme.cardBorder
        opacity: Components.Theme.opacityDisabled
    }
    
    MouseArea {
        id: rowArea
        anchors.fill: parent
        cursorShape: rowRoot.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        enabled: rowRoot.interactive
        onClicked: rowRoot.clicked()
    }
}
