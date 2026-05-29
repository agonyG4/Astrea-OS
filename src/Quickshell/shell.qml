//@ pragma IconTheme WhiteSur-dark
import Quickshell
import QtQuick
import Quickshell.Io
import "./bar"
import "./desktop" as Desktop
import "./island"
import "./notifications"
import "./runtime" as Runtime
import "./spotlight"
import "./alttab"
import "./auth" as Auth

ShellRoot {
    id: root

    property bool polkitProbeDone: false
    property bool polkitAgentEnabled: false
    readonly property bool forcePolkitAgent: (Quickshell.env("ASTREA_FORCE_POLKIT_AGENT") || "") === "1"

    Runtime.ComponentSettings { id: componentSettings }
    Runtime.ShellRuntime {
        id: shellRuntime
        componentSettings: componentSettings
    }
    Runtime.ComponentServiceManager {
        componentSettings: componentSettings
        gameModeActive: shellRuntime.gameModeActive
    }

    Component.onCompleted: polkitProbe.running = true

    Process {
        id: polkitProbe
        command: [
            "bash",
            "-c",
            "ps -eo pid=,comm=,args= | awk -v self=\"$PPID\" '$2 == \"quickshell\" && $0 ~ /shell[.]qml/ && $1 != self { found = 1 } END { print found ? \"existing\" : \"none\" }'"
        ]
        running: false
        stdout: StdioCollector { id: polkitProbeOut }
        onExited: {
            root.polkitAgentEnabled = root.forcePolkitAgent || polkitProbeOut.text.trim() !== "existing"
            root.polkitProbeDone = true
        }
    }

    Loader {
        active: root.polkitProbeDone && root.polkitAgentEnabled
        sourceComponent: Auth.AstreaPolkitAgent {}
    }

    Desktop.DesktopIconsLoader {
        componentEnabled: componentSettings.desktop
        gameModeActive: shellRuntime.gameModeActive
    }

    // Bar — one per screen
    Variants {
        model: componentSettings.topbar ? Quickshell.screens : []
        delegate: Bar {
            required property var modelData
            screen: modelData
            sharedMusicState: shellRuntime.musicState
            sharedNetworkState: shellRuntime.networkState
            sharedBluetoothState: shellRuntime.bluetoothState
            sharedAudioState: shellRuntime.audioState
            externalVolumeOsdSerial: shellRuntime.volumeOsdSerial
            externalVolumeOsdLevel: shellRuntime.volumeOsdLevel
            externalVolumeOsdMuted: shellRuntime.volumeOsdMuted
        }
    }

    Variants {
        model: componentSettings.island ? Quickshell.screens : []
        delegate: Island {
            required property var modelData
            screen: modelData
            sharedMusicState: shellRuntime.musicState
            gamemodeActive: shellRuntime.gameModeActive
        }
    }

    Loader {
        active: componentSettings.spotlight
        sourceComponent: Spotlight {
            performancePaused: shellRuntime.gameModeActive
        }
    }

    Loader {
        active: componentSettings.alttab
        sourceComponent: AltTab {}
    }

    Loader {
        active: componentSettings.notifications
        sourceComponent: Notifications {}
    }
}
