//@ pragma UseQApplication
//@ pragma IconTheme WhiteSur-dark
import Quickshell
import QtQuick
import "./bar"
import "./desktop" as Desktop
import "./island"
import "./notifications"
import "./runtime" as Runtime
import "./spotlight"
import "./alttab"

ShellRoot {
    id: root

    Runtime.ShellRuntime { id: shellRuntime }

    Desktop.DesktopIconsLoader {
        gameModeActive: shellRuntime.gameModeActive
    }

    // Bar — one per screen
    Variants {
        model: Quickshell.screens
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
        model: Quickshell.screens
        delegate: Island {
            required property var modelData
            screen: modelData
            sharedMusicState: shellRuntime.musicState
            gamemodeActive: shellRuntime.gameModeActive
        }
    }

    Spotlight {
        performancePaused: shellRuntime.gameModeActive
    }

    AltTab {}

    Notifications {}
}
