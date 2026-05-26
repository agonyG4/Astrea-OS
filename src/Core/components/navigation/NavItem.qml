import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
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
    property int leftInset: 0
    property bool compact: false
    required property bool   selected
    signal clicked()

    readonly property color accent: Components.Theme.accent
    readonly property bool isLight: Components.Theme.themeMode === 1
    readonly property color idleForeground: isLight ? Components.Theme.textSecondary : Qt.rgba(1, 1, 1, 0.78)
    readonly property color accentForeground: Components.Theme.accentForeground
    readonly property color activeForeground: Components.Theme.textPrimary
    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT")
        || (Quickshell.env("HOME") + "/.local/share/Astrea")

    // ── Fundo ─────────────────────────────────────────────────────────────
    Rectangle {
        id: bgRect
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius: 8
        color: root.selected
            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
            : hma.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.045) : Qt.rgba(1, 1, 1, 0.05)) : "transparent"
        border.width: root.selected ? 1 : (hma.containsMouse ? 1 : 0)
        border.color: root.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.05))
        
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
        anchors { fill: parent; leftMargin: 16 + root.leftInset; rightMargin: 12 }
        spacing: root.compact ? 10 : 12

        Rectangle {
            width:  root.compact ? 24 : 28
            height: root.compact ? 24 : 28
            radius: root.compact ? 7 : 8
            color: root.selected ? root.accent : (hma.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.1)) : (root.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.05)))
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // Adds a gentle inner shadow / highlight effect overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: root.isLight ? Qt.rgba(0, 0, 0, root.selected ? 0.08 : 0.05) : Qt.rgba(1, 1, 1, root.selected ? 0.2 : 0.08)
            }

            Text {
                anchors.centerIn: parent
                text:           root.sym
                color:          root.selected ? root.accentForeground : (hma.containsMouse ? root.activeForeground : root.idleForeground)
                font.pixelSize: root.compact ? Components.Theme.fontSizeSmall : Components.Theme.fontSizeNormal
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
                        return "file://" + root.astreaRoot + "/Assets/icons/settings/themes/"
                               + Components.Theme.iconTheme + "/" + root.iconKey + ".svg"
                    return ""
                }
                readonly property string fallbackSource: root.iconSource !== ""
                    ? root.iconSource
                    : (root.iconKey !== "" ? "file://" + root.astreaRoot + "/Assets/icons/settings/" + root.iconKey + ".svg" : "")
                readonly property string resolvedSource: {
                    if (themedPath !== "" && !themedFailed)
                        return themedPath
                    return fallbackSource
                }
                property bool themedFailed: false

                // Reset failed state when theme or key changes
                onThemedPathChanged: themedFailed = false

                source: resolvedSource
                visible: resolvedSource !== ""

                onStatusChanged: {
                    if (status === Image.Error && source === themedPath && !themedFailed) {
                        themedFailed = true
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
                    colorizationColor: root.selected ? root.accentForeground : (hma.containsMouse ? root.activeForeground : root.idleForeground)
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
            color:       root.selected ? root.activeForeground : (hma.containsMouse ? root.activeForeground : root.idleForeground)
            font.family: Components.Theme.fontFamily
            font.pixelSize: root.compact ? Components.Theme.fontSizeSmall : Components.Theme.fontSizeNormal
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
