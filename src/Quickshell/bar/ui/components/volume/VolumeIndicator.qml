import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.IndicatorButton {
    id: root

    property int  volLevel:    50
    property bool volMuted:    false
    property var  volPopupRef: null

    signal volChanged(int v)

    popupRef: root.volPopupRef

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
        color: root.volMuted ? Theme.iconMuted : Theme.iconMain
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
        Behavior on color { ColorAnimation { duration: Theme.animationFast } }
    }
}
