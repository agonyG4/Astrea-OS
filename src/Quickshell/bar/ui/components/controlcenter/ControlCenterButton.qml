import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../system/base" as SystemComponents
import "../../.."

SystemComponents.TopbarIndicator {
    id: root

    readonly property string quickshellAssetRoot: "file://" + (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Assets/ui/quickshell/bar/"

    fixedWidth: 36
    height: 36
    backgroundMargin: 4
    backgroundRadius: Theme.radiusMedium
    hoverColor: Qt.rgba(1, 1, 1, 0.05)
    pressedColor: Qt.rgba(1, 1, 1, 0.10)

    Image {
        id: icon
        width: 16; height: 16
        source: root.quickshellAssetRoot + "topbar/control-center.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: root.pressed ? 0.7 : 1.0

        layer.enabled: true
        layer.smooth: true
        layer.effect: ColorOverlay {
            color: Theme.iconActive
        }
    }
}
