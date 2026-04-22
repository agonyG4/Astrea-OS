import Quickshell
import Quickshell.Io
import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.TopbarPopup {
    id: root

    popupWidth: 200
    cardPadding: 12
    contentSpacing: 4
    backgroundColor: Theme.background
    borderColor: Theme.border

    MenuItem {
        icon: "󰍉"; text: "Search"
        onClicked: { root.close(); shellLauncher.running = true }
    }

    MenuSeparator {}

    MenuItem {
        icon: "󰋖"; text: "About this PC"
        onClicked: {
            root.close()
            shellAbout.running = false
            Qt.callLater(() => { shellAbout.running = true })
        }
    }
    MenuItem {
        icon: "󰍜"; text: "Settings"
        onClicked: {
            root.close()
            shellSettings.running = false
            Qt.callLater(() => { shellSettings.running = true })
        }
    }

    MenuSeparator {}

    MenuItem {
        icon: "󰅙"; text: "Force Quit"
        onClicked: { root.close(); shellForceQuit.running = true }
    }
    MenuItem {
        icon: "󰷛"; text: "Lockscreen"
        onClicked: { root.close(); shellLock.running = true }
    }
    MenuItem {
        icon: "󰐥"; text: "Power"
        onClicked: { root.close(); shellPower.running = true }
    }

    // ─── Processos ────────────────────────────────────────────────
    Process { id: shellLauncher;  command: ["rofi", "-show", "drun"] }
    Process { id: shellAbout;    command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/share/Astrea/Apps/about.qml"] }
    Process { id: shellSettings; command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/share/Astrea/Apps/Settings/main.qml"] }
    Process { id: shellForceQuit; command: ["bash", "-c", "hyprctl kill"] }
    Process { id: shellLock; command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/share/Astrea/Features/Paper/lockscreen/lockscreen.qml"] }
    Process { id: shellPower;     command: ["bash", "-c", "shutdown now"] }
}
