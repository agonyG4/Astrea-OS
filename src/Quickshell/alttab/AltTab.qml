import Quickshell
import Quickshell.Hyprland
import QtQuick
import "./core" as Core
import "./ui" as Ui

ShellRoot {
    id: root

    Core.AltTabController {
        id: switcher
    }

    HyprlandFocusGrab {
        active: switcher.open
    }

    Loader {
        active: switcher.open
        asynchronous: true

        sourceComponent: Ui.AltTabView {
            controller: switcher
        }
    }
}
