import QtQuick
import QtQuick.Layouts
import ".." as Components

Item {
    id: labelRoot
    property string text: ""
    property color textSecondary: Components.Theme.textSecondary
    property color textHighlight: "#ffffff" // A slightly brighter option
    
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    Layout.fillWidth: true

    RowLayout {
        id: layout
        spacing: Components.Theme.spacing
        anchors.fill: parent

        Text {
            text: labelRoot.text
            font.family: Components.Theme.fontFamily
            font.pixelSize: Components.Theme.fontSizeSmall
            font.weight: Components.Theme.fontWeightBold
            font.letterSpacing: Components.Theme.trackingHeader
            color: labelRoot.textSecondary
            elide: Text.ElideRight
            Layout.maximumWidth: Math.min(260, Math.max(120, labelRoot.width * 0.45))
            
            // Add a very subtle inner shadow if needed, or just crisp text
            renderType: Text.NativeRendering
        }

        // Modern UI subtle dash line stretching next to the header
        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 1
            color: Qt.rgba(labelRoot.textSecondary.r, labelRoot.textSecondary.g, labelRoot.textSecondary.b, 0.22)
            // Just a small gradient fade out effect is premium
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(labelRoot.textSecondary.r, labelRoot.textSecondary.g, labelRoot.textSecondary.b, 0.38) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
