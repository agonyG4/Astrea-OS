import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: overlay

    property var control: null
    property bool open: false
    readonly property int overlayWidth: Math.round(Math.min(760, Math.max(660, (screen ? screen.width : 1280) * 0.40)))
    readonly property int overlayHeight: Math.round(Math.min(640, Math.max(560, (screen ? screen.height : 720) - 240)))
    signal addRequested(string kind)
    signal doneRequested()

    visible: open
    color: "transparent"
    anchors.top: true
    anchors.left: true
    implicitWidth: overlayWidth
    implicitHeight: overlayHeight

    WlrLayershell.namespace: "control-center-widget-library"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.margins.left: Math.round(Math.max(24, ((screen ? screen.width : 1280) - overlayWidth) / 2))
    WlrLayershell.margins.top: Math.round(Math.max(70, ((screen ? screen.height : 720) - overlayHeight) / 2))

    WidgetLibraryPanel {
        anchors.fill: parent
        control: overlay.control
        onAddRequested: kind => overlay.addRequested(kind)
        onDoneRequested: overlay.doneRequested()
    }
}
