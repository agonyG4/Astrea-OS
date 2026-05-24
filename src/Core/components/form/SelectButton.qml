import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import ".." as Components

Item {
    id: sel

    // ── Interface ─────────────────────────────────────────────────────────
    property string label: ""
    property var    options: []
    property int    selectedIndex: -1
    property string popupDirection: "down" // Adicionando a propriedade
    signal selected(int index)
    property bool isButton: false

    // ── Styling (Premium Defaults) ───────────────────────────────
    property color accent: Components.Theme.accent
    property color textPrimary: Components.Theme.textPrimary
    property color textSecondary: Components.Theme.textSecondary
    property color cardBg: Components.Theme.cardBg
    property color cardBorder: Components.Theme.cardBorder
    property color popupBg: Components.Theme.popupBg

    implicitHeight: 36

    readonly property int maxVisible: 5
    readonly property int itemH:      36
    readonly property int popupPad:   Components.Theme.spacingSmall
    readonly property int listH: Math.min(sel.options.length, sel.maxVisible) * sel.itemH + popupPad * 2
    readonly property bool isLight: Components.Theme.themeMode === 1
    readonly property bool isDefaultLight: isLight && Components.Theme.shellStyle === 1
    readonly property color restingBg: isDefaultLight ? Qt.rgba(0.975, 0.978, 0.986, 1) : sel.cardBg
    readonly property color hoverBg: isLight ? Qt.rgba(0, 0, 0, 0.045) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color pressedBg: isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color popupHoverBg: isLight ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color popupBorder: isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color popupShadow: isLight ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.73)

    // ── Main Button ───────────────────────────────────────────────────────
    Rectangle {
        id: btnRect
        anchors.fill: parent
        radius: Components.Theme.controlRadius
        color: btnArea.pressed ? sel.pressedBg : (btnArea.containsMouse ? sel.hoverBg : sel.restingBg)
        border.width: 1
        border.color: (dropdown.visible || btnArea.pressed) ? sel.accent : sel.cardBorder
        
        // Premium Micro-animations
        scale: btnArea.pressed ? 0.96 : (dropdown.visible ? 0.98 : 1.0)
        Behavior on scale { NumberAnimation { duration: Components.Theme.animationFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Components.Theme.animationNormal } }
        Behavior on border.color { ColorAnimation { duration: Components.Theme.animationNormal } }

        RowLayout {
            anchors { fill: parent; leftMargin: Components.Theme.spacingMedium; rightMargin: Components.Theme.spacingMedium }
            spacing: Components.Theme.spacing
            Text {
                Layout.fillWidth: true
                text: sel.label
                color: sel.textPrimary
                font.family: Components.Theme.fontFamily
                font.pixelSize: Components.Theme.fontSizeNormal
                font.weight: Components.Theme.fontWeightMedium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }
            }
            Text {
                visible: !sel.isButton
                text: dropdown.visible ? "⌃" : "⌄"
                color: dropdown.visible ? sel.accent : sel.textSecondary
                font.pixelSize: Components.Theme.fontSizeNormal
                Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }
                
                // Add a subtle rotation instead of snapping character
                rotation: dropdown.visible ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Components.Theme.animationNormal; easing.type: Easing.OutBack } }
            }
            Text {
                visible: sel.isButton
                text: "\uf03e" // Icon font usually
                font.family: "JetBrainsMono Nerd Font"
                color: btnArea.containsMouse ? sel.accent : sel.textSecondary
                font.pixelSize: Components.Theme.fontSizeNormal
                Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }
            }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (sel.isButton) sel.selected(-1)
                else dropdown.visible ? dropdown.close() : dropdown.open()
            }
        }
    }

    // ── Dialog (Popup) ────────────────────────────────────────────────────
    Popup {
        id: dropdown
        y: sel.popupDirection === "up" ? -(sel.listH + 6) : sel.height + 6
        width: Math.max(sel.width, 160)
        height: sel.listH
        padding: sel.popupPad
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        visible: false
        enabled: !sel.isButton
        
        // Anchor the popup scaling based on direction
        transformOrigin: sel.popupDirection === "up" ? Item.Bottom : Item.Top

        background: Rectangle {
            id: popupBgRect
            radius: Components.Theme.cornerRadiusLarge
            color: sel.popupBg
            border.width: 1
            border.color: sel.popupBorder
            
            // Drop shadow directly attached using layer if MultiEffect isn't globally available here
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: sel.popupShadow
                shadowBlur: 1.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 6
            }
        }

        // Extremely snappy/premium enter transition
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Components.Theme.animationNormal; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: Components.Theme.animationPopover; easing.type: Easing.OutElastic; easing.amplitude: 0.8 }
                NumberAnimation { property: "y"; from: sel.popupDirection === "up" ? -(sel.listH + 1) : sel.height - 5; to: sel.popupDirection === "up" ? -(sel.listH + 6) : sel.height + 6; duration: Components.Theme.animationSlow; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Components.Theme.animationFast; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: Components.Theme.animationFast; easing.type: Easing.InCubic }
                NumberAnimation { property: "y"; from: sel.popupDirection === "up" ? -(sel.listH + 6) : sel.height + 6; to: sel.popupDirection === "up" ? -(sel.listH + 2) : sel.height + 2; duration: Components.Theme.animationFast; easing.type: Easing.InCubic }
            }
        }

        contentItem: ListView {
            id: listView
            clip: true
            model: sel.options
            spacing: Components.Theme.spacingMicro
            boundsBehavior: Flickable.StopAtBounds
            onVisibleChanged: if (visible && sel.selectedIndex >= 0) positionViewAtIndex(sel.selectedIndex, ListView.Contain)

            ScrollBar.vertical: ScrollBar {
                policy: sel.options.length > sel.maxVisible ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                readonly property bool active: sel.selectedIndex === index
                width: listView.width
                height: sel.itemH
                radius: Components.Theme.cornerRadiusSmall
                color: rowArea.pressed 
                       ? Qt.rgba(sel.accent.r, sel.accent.g, sel.accent.b, 0.25)
                       : (active ? Qt.rgba(sel.accent.r, sel.accent.g, sel.accent.b, 0.15) 
                                 : (rowArea.containsMouse ? sel.popupHoverBg : "transparent"))
                
                scale: rowArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: Components.Theme.animationMicro } }
                Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }

                RowLayout {
                    anchors { fill: parent; leftMargin: Components.Theme.spacingMedium; rightMargin: Components.Theme.spacingMedium }
                    Text {
                        Layout.fillWidth: true
                        text: modelData
                        color: active ? sel.accent : sel.textPrimary
                        font.family: Components.Theme.fontFamily
                        font.pixelSize: Components.Theme.fontSizeNormal
                        font.weight: active ? Components.Theme.fontWeightDemiBold : Components.Theme.fontWeightMedium
                        Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }
                    }
                    Text {
                        visible: active
                        text: "✓"
                        color: sel.accent
                        font.pixelSize: Components.Theme.fontSizeNormal
                        font.weight: Components.Theme.fontWeightBold
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { sel.selected(index); dropdown.close() }
                }
            }
        }
    }
}
