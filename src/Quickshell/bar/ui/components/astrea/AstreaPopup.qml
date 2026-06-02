import Quickshell
import Quickshell.Io
import QtQuick
import "../system/popups" as SystemComponents
import "../../.."
import "../../../../AstreaI18n" as AstreaI18n

SystemComponents.TopbarPopup {
    id: root

    popupWidth: 200
    cardPadding: 12
    contentSpacing: 4
    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")

    MenuItem {
        icon: "󰍉"; text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.menu.search"]) || "Search"
        onClicked: { root.close(); shellLauncher.running = true }
    }

    MenuSeparator {}

    MenuItem {
        icon: "󰋖"; text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.menu.about"]) || "About this PC"
        onClicked: {
            root.close()
            shellAbout.running = false
            Qt.callLater(() => { shellAbout.running = true })
        }
    }
    MenuItem {
        icon: "󰍜"; text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.menu.settings"]) || "Settings"
        onClicked: {
            root.close()
            shellSettings.running = false
            Qt.callLater(() => { shellSettings.running = true })
        }
    }

    MenuSeparator {}

    MenuItem {
        icon: "󰅙"; text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.menu.force_quit"]) || "Force Quit"
        onClicked: { root.close(); shellForceQuit.running = true }
    }
    MenuItem {
        icon: "󰷛"; text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.menu.lockscreen"]) || "Lockscreen"
        onClicked: { root.close(); shellLock.running = true }
    }
    MenuItem {
        icon: "󰐥"; text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.menu.power"]) || "Power"
        onClicked: { root.close(); shellPower.running = true }
    }

    // ─── Processos ────────────────────────────────────────────────
    Process { id: shellLauncher;  command: ["rofi", "-show", "drun"] }
    Process { id: shellAbout;    command: ["quickshell", "-p", root.astreaRoot + "/Apps/About/main.qml"] }
    Process { id: shellSettings; command: [root.astreaRoot + "/bin/astrea-settings-open"] }
    Process { id: shellForceQuit; command: ["hyprctl", "kill"] }
    Process { id: shellLock; command: ["quickshell", "-p", root.astreaRoot + "/Features/Paper/lockscreen/lockscreen.qml"] }
    Process { id: shellPower;     command: ["shutdown", "now"] }
}
