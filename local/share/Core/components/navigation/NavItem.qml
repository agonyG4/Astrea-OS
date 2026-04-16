import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".." as Components

Item {
    id: root

    height: 40

    required property string label
    property string sym: ""
    property string iconSource: ""
    // iconKey: filename without extension (e.g. "display"). When set,
    // the component tries the themed path first and falls back to iconSource.
    property string iconKey: ""
    required property bool   selected
    signal clicked()

    readonly property color accent: Components.Theme.accent

    // ── Fundo ─────────────────────────────────────────────────────────────
    Rectangle {
        id: bgRect
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius: 8
        color: root.selected
            ? Qt.rgba(0.04, 0.52, 1, 0.12)
            : hma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        border.width: root.selected ? 1 : (hma.containsMouse ? 1 : 0)
        border.color: root.selected ? Qt.rgba(0.04, 0.52, 1, 0.25) : Qt.rgba(1, 1, 1, 0.05)
        
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // Subtle left indicator for selected state
        Rectangle {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 3
            height: root.selected ? parent.height * 0.5 : 0
            radius: 1.5
            color: root.accent
            opacity: root.selected ? 1.0 : 0.0
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // ── Conteúdo ──────────────────────────────────────────────────────────
    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
        spacing: 12

        Rectangle {
            width:  28
            height: 28
            radius: 8
            color: root.selected ? root.accent : (hma.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // Adds a gentle inner shadow / highlight effect overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, root.selected ? 0.2 : 0.08)
            }

            Text {
                anchors.centerIn: parent
                text:           root.sym
                color:          root.selected ? "#ffffff" : (hma.containsMouse ? "#ffffff" : "#98989f")
                font.pixelSize: Components.Theme.fontSizeNormal
                font.family:    "JetBrainsMono Nerd Font"
                visible:        root.iconSource === ""
                Behavior on color { ColorAnimation { duration: 150 } }
                
                // Active glow for the icon
                layer.enabled: root.selected && visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.accent
                    shadowBlur: 0.8
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }

            Image {
                id: navIcon
                anchors.fill: parent

                // ── Themed icon resolution with fallback ───────────────────
                // Build themed path when iconKey is set and a theme is active.
                readonly property string themedPath: {
                    if (root.iconKey !== "" && Components.Theme.iconTheme !== "")
                        return "file:///home/agony/.local/share/Astrea/Assets/icons/settings/icon/"
                               + Components.Theme.iconTheme + "/" + root.iconKey + ".svg"
                    return ""
                }
                readonly property bool themedLoading: themedPath !== ""
                property bool themedFailed: false

                // Reset failed state when theme or key changes
                onThemedPathChanged: themedFailed = false

                source: {
                    if (themedLoading && !themedFailed)
                        return themedPath
                    if (root.iconSource !== "")
                        return root.iconSource
                    return ""
                }
                visible: source !== ""

                onStatusChanged: {
                    if (status === Image.Error && themedLoading && !themedFailed) {
                        themedFailed = true   // triggers re-evaluation → falls back to iconSource
                    }
                }

                sourceSize: Qt.size(parent.width * 2, parent.height * 2)
                fillMode: Image.Stretch
                mipmap: true
                smooth: true

                // dark mode (1): show native SVG colors, no colorization
                // clear mode (0) / light mode (2): apply color tint
                layer.enabled: visible && Components.Theme.iconStyle !== 1
                layer.effect: MultiEffect {
                    colorizationColor: root.selected ? "#ffffff" : (hma.containsMouse ? "#ffffff" : "#98989f")
                    colorization: 1.0
                    shadowEnabled: root.selected
                    shadowColor: root.accent
                    shadowBlur: 0.8
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
        }

        Text {
            text:        root.label
            color:       root.selected ? "#ffffff" : (hma.containsMouse ? "#ffffff" : "#98989f")
            font.family: Components.Theme.fontFamily
            font.pixelSize: Components.Theme.fontSizeNormal
            font.weight: root.selected ? Components.Theme.fontWeightDemiBold : Components.Theme.fontWeightMedium
            elide:       Text.ElideRight
            Layout.fillWidth: true
            scale: hma.pressed ? 0.97 : 1.0
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }

    // ── Interação ─────────────────────────────────────────────────────────
    MouseArea {
        id: hma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.clicked()
    }
}
