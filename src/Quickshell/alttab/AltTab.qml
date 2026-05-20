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

    Ui.AltTabView {
        controller: switcher
    }
}
