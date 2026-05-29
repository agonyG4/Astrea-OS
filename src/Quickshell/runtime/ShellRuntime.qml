import Quickshell.Io
import QtQuick
import "../bar/modules/audio"
import "../bar/modules/bluetooth"
import "../bar/modules/network"
import "../island/modes/music" as Music

Item {
    id: root

    property var componentSettings: null
    readonly property bool topbarEnabled: !componentSettings || componentSettings.topbar
    readonly property bool islandEnabled: !componentSettings || componentSettings.island
    readonly property bool musicMonitoringEnabled: topbarEnabled || islandEnabled

    readonly property var musicState: musicLoader.item
    readonly property var networkState: networkLoader.item
    readonly property var bluetoothState: bluetoothLoader.item
    readonly property var audioState: audioLoader.item
    property alias gameModeState: gameMode
    readonly property bool gameModeActive: gameMode.active

    property int volumeOsdSerial: 0
    property int volumeOsdLevel: 50
    property bool volumeOsdMuted: false

    function showVolumeOsd(level, muted) {
        root.volumeOsdLevel = Math.max(0, Math.min(150, level))
        root.volumeOsdMuted = muted
        root.volumeOsdSerial += 1
    }

    GameModeManager {
        id: gameMode
    }

    Loader {
        id: musicLoader
        active: root.musicMonitoringEnabled
        sourceComponent: Music.MusicMonitor {
            performancePaused: false
        }
    }

    Loader {
        id: networkLoader
        active: root.topbarEnabled
        sourceComponent: NetworkProcess {
            performancePaused: root.gameModeActive
        }
    }

    Loader {
        id: bluetoothLoader
        active: root.topbarEnabled
        sourceComponent: BluetoothProcess {
            performancePaused: root.gameModeActive
        }
    }

    Loader {
        id: audioLoader
        active: root.topbarEnabled
        sourceComponent: AudioProcess {
            performancePaused: root.gameModeActive
            onVolumeChanged: (level, muted) => root.showVolumeOsd(level, muted)
        }
    }

    IpcHandler {
        target: "astrea-osd"

        function showVolume(level: int, muted: bool): void {
            root.showVolumeOsd(level, muted)
            if (root.audioState) {
                root.audioState.level = root.volumeOsdLevel
                root.audioState.muted = muted
            }
        }
    }
}
