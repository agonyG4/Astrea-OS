import QtQuick
import Quickshell
import "../system/base" as SystemComponents
import "../../.."

SystemComponents.TopbarIndicator {
    id: root

    readonly property string quickshellAssetRoot: "file://" + (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Assets/ui/quickshell/bar/"

    fixedWidth: 28
    height: 36
    backgroundMargin: Theme.spacingTiny
    backgroundRadius: Theme.radiusMedium
    hoverColor: Theme.shellHover
    pressedColor: Theme.shellPressed

    Image {
        id: icon
        width: 16; height: 16
        source: root.quickshellAssetRoot + "topbar/control-center.png"
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: root.pressed ? 0.7 : 1.0
    }
}
