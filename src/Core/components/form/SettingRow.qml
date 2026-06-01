import QtQuick
import QtQuick.Layouts
import ".." as Components

Item {
    id: sr
    property string label: ""
    property string sublabel: ""
    property bool   isLast:  false
    property bool   clickable: false
    property bool   controlBlocksRowClick: true
    
    // Theme colors
    property color textPrimary: Components.Theme.textPrimary
    property color textSecondary: Components.Theme.textSecondary
    property color cardBorder: Components.Theme.cardBorder
    property color rowHoverBg:    Qt.rgba(1, 1, 1, 0.055)

    default property alias control: slot.data
    implicitWidth: parent ? parent.width : 200
    implicitHeight: Math.max(sr.sublabel !== "" ? 64 : 52, rowLayout.implicitHeight + Components.Theme.spacingMedium * 2)

    // Interactive subtle hover background
    Rectangle {
        id: bgHighlight
        anchors { fill: parent; leftMargin: Components.Theme.spacingMicro; rightMargin: Components.Theme.spacingMicro; topMargin: Components.Theme.spacingTiny; bottomMargin: Components.Theme.spacingTiny }
        radius: Components.Theme.controlRadius
        color: rowArea.containsMouse && sr.clickable ? sr.rowHoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: Components.Theme.animationSlow; easing.type: Easing.OutQuart } }
    }

    RowLayout {
        id: rowLayout
        anchors { fill: parent; leftMargin: Components.Theme.spacingXLarge; rightMargin: Components.Theme.spacingXLarge }
        spacing: Components.Theme.spacingLarge

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Components.Theme.spacingMicro
            
            Text { 
                text: sr.label; 
                color: sr.textPrimary; 
                font.family: Components.Theme.fontFamily
                font.pixelSize: Components.Theme.fontSizeLarge; 
                font.weight: Components.Theme.fontWeightMedium 
                Layout.fillWidth: true
                elide: Text.ElideRight
                // Subtle scale or translation could theoretically be added here
            }
            Text {
                visible: sr.sublabel !== ""; 
                text: sr.sublabel
                color: sr.textSecondary; 
                font.family: Components.Theme.fontFamily
                font.pixelSize: Components.Theme.fontSizeSmall; 
                font.weight: Components.Theme.fontWeightNormal
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: slot
            implicitWidth:  children.length > 0 ? Math.max(children[0].implicitWidth, children[0].width)  : 0
            implicitHeight: children.length > 0 ? Math.max(children[0].implicitHeight, children[0].height) : 0
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.maximumWidth: Math.max(0, sr.width - rowLayout.anchors.leftMargin - rowLayout.anchors.rightMargin)
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            scale: rowArea.pressed && sr.clickable ? 0.98 : 1.0
            Behavior on scale { NumberAnimation { duration: Components.Theme.animationFast; easing.type: Easing.OutCubic } }
        }
    }

    Rectangle {
        visible: !sr.isLast
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Components.Theme.spacingXLarge }
        height: 1; 
        color: sr.cardBorder
    }

    signal rightClicked(real x, real y)
    signal clicked()

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true
        cursorShape: sr.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function isOverControl(mouse) {
            if (!sr.controlBlocksRowClick)
                return false
            const p = mapToItem(slot, mouse.x, mouse.y)
            return p.x >= 0 && p.x <= slot.width && p.y >= 0 && p.y <= slot.height
        }
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true
            } else if (rowArea.isOverControl(mouse)) {
                mouse.accepted = false
            } else if (sr.clickable) {
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                sr.rightClicked(mouse.x, mouse.y)
            } else if (rowArea.isOverControl(mouse)) {
                mouse.accepted = false
            } else if (sr.clickable) {
                sr.clicked()
            } else {
                mouse.accepted = false
            }
        }
        onReleased: (mouse) => {
            if (mouse.button !== Qt.RightButton && (!sr.clickable || rowArea.isOverControl(mouse))) {
                mouse.accepted = false
            }
        }
    }
}
