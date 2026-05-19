import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../components"

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
                    color: "#80323232"
                    border.color: "#30FFFFFF"
                    border.width: 1
                    clip: true

                    scale: root.open ? 1 : 0.96
                    opacity: root.open ? 1 : 0

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

                                width: 92
                                height: 92
                                radius: 22
                                color: index === root.controller.currentIndex ? "#347DFF" : "transparent"
                                border.color: index === root.controller.currentIndex ? "#88FFFFFF" : "transparent"
                                border.width: 1
                                scale: index === root.controller.currentIndex ? 1.06 : 1.0

                                Behavior on color { ColorAnimation { duration: 90 } }
                                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                AppIcon {
                                    anchors.centerIn: parent
                                    width: 74
                                    height: 74
                                    entry: modelData
                                    fallbackRadius: 18
                                    fallbackColor: "#24FFFFFF"
                                    fallbackFontSize: 27
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
