import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    property int thickness: 6
    property int rounding: 14
    property color borderColor: "#cba6f7"

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            required property var modelData

            PanelWindow {
                screen: modelData
                WlrLayershell.namespace: "caelestia-border-exclusion"
                WlrLayershell.layer: WlrLayer.Top
                anchors { top: true; bottom: true; left: true; right: true }
                exclusiveZone: thickness
                color: "transparent"
            }

            PanelWindow {
                screen: modelData
                WlrLayershell.namespace: "caelestia-border"
                WlrLayershell.layer: WlrLayer.Overlay
                anchors { top: true; bottom: true; left: true; right: true }
                exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"

                // Mask só nas 4 bordas — o resto da tela passa clique
                mask: Region {
                    Region { item: borderTop }
                    Region { item: borderBottom }
                    Region { item: borderLeft }
                    Region { item: borderRight }
                }

                Rectangle {
                    id: borderTop
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: thickness
                    color: borderColor
                    radius: rounding
                }
                Rectangle {
                    id: borderBottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: thickness
                    color: borderColor
                    radius: rounding
                }
                Rectangle {
                    id: borderLeft
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: thickness
                    color: borderColor
                    radius: rounding
                }
                Rectangle {
                    id: borderRight
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: thickness
                    color: borderColor
                    radius: rounding
                }
            }
        }
    }
}
