import QtQuick
import "../system/base" as SystemComponents
import "../../.."

SystemComponents.TopbarIndicator {
    id: root

    property int  volLevel:    50
    property bool volMuted:    false

    signal volChanged(int v)

    onWheel: event => {
        var d = event.angleDelta.y > 0 ? 2 : -2
        var v = Math.max(0, Math.min(100, root.volLevel + d))
        root.volChanged(v)
    }

    Text {
        text: root.volMuted      ? "󰝟"
            : root.volLevel < 34 ? "󰕿"
            : root.volLevel < 67 ? "󰖀"
            :                      "󰕾"
        color: root.volMuted ? Theme.shellIconMuted : Theme.shellIconMain
        font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
        Behavior on color { ColorAnimation { duration: Theme.animationFast } }
    }
}
