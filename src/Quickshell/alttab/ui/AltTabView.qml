import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../components"
import "../../AstreaComponents" as UI

Item {
    id: root

    property var controller: null
    readonly property bool open: controller !== null && controller.open

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            visible: root.open && modelData === Quickshell.screens[0]
            color: "transparent"

            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true

            WlrLayershell.namespace: "astrea-alt-tab"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusiveZone: -1

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: root.open
                activeFocusOnTab: true

                Keys.onEscapePressed: root.controller.cancel()
                Keys.onReturnPressed: root.controller.commit()
                Keys.onEnterPressed: root.controller.commit()
                Keys.onRightPressed: root.controller.step(1)
                Keys.onLeftPressed: root.controller.step(-1)
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) {
                        event.accepted = true
                        root.controller.commit()
                    }
                }

                Component.onCompleted: if (root.open) forceActiveFocus()
                onVisibleChanged: if (visible) forceActiveFocus()

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.controller.cancel()
                }

                Rectangle {
                    id: panel
                    anchors.centerIn: parent
                    width: Math.min(Math.max(220, appRow.implicitWidth + 34), parent.width - 120)
                    height: 116
                    radius: 26
                    color: UI.Theme.windowBackground
                    border.color: UI.Theme.windowBorder
                    border.width: 1
                    clip: true

                    scale: root.open ? 1 : 0.96
                    opacity: root.open ? 1 : 0

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: UI.Theme.windowWash
                        visible: UI.Theme.windowWash.a > 0
                    }

                    Behavior on color { ColorAnimation { duration: UI.Theme.animationFast; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 90 } }

                    Row {
                        id: appRow
                        anchors.centerIn: parent
                        spacing: 12

                        Repeater {
                            model: root.controller ? root.controller.clients : []

                            delegate: Rectangle {
                                required property int index
                                required property var modelData
                                readonly property bool selected: index === root.controller.currentIndex

                                width: 92
                                height: 92
                                radius: 22
                                color: "transparent"

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: selected
                                        ? Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, UI.Theme.isLight ? 0.20 : 0.28)
                                        : "transparent"
                                    border.color: selected
                                        ? Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, UI.Theme.isLight ? 0.34 : 0.46)
                                        : "transparent"
                                    border.width: 1
                                    scale: selected ? 1.06 : 1.0

                                    Behavior on color { ColorAnimation { duration: 90 } }
                                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                }

                                AppIcon {
                                    anchors.centerIn: parent
                                    width: selected ? 84 : 72
                                    height: width
                                    entry: modelData
                                    iconRadius: selected ? 18 : 15
                                    fallbackRadius: iconRadius
                                    fallbackColor: UI.Theme.cardBg
                                    fallbackFontSize: 27
                                    showFallbackText: !modelData.hideIconFallback

                                    Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                    Behavior on iconRadius { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.controller.preview(index)
                                    onClicked: root.controller.commitIndex(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
