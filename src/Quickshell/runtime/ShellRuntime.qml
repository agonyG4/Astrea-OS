import Quickshell.Io
import QtQuick
import "../bar/modules/audio"
import "../bar/modules/bluetooth"
import "../bar/modules/network"
import "../island/modes/music" as Music

Item {
    id: root

    property alias musicState: musicMonitor
    property alias networkState: networkStatus
    property alias bluetoothState: bluetoothStatus
    property alias audioState: audioStatus
    property alias gameModeState: gameMode
    readonly property bool gameModeActive: gameMode.active

    property int volumeOsdSerial: 0
    property int volumeOsdLevel: 50
    property bool volumeOsdMuted: false

    GameModeManager {
        id: gameMode
    }

    Music.MusicMonitor {
        id: musicMonitor
        performancePaused: gameMode.active
    }

    NetworkProcess {
        id: networkStatus
    }

    BluetoothProcess {
        id: bluetoothStatus
    }

    AudioProcess {
        id: audioStatus
    }

    IpcHandler {
        target: "astrea-osd"

        function showVolume(level: int, muted: bool): void {
            root.volumeOsdLevel = Math.max(0, Math.min(150, level))
            root.volumeOsdMuted = muted
            audioStatus.level = root.volumeOsdLevel
            audioStatus.muted = muted
            root.volumeOsdSerial += 1
        }
    }
}
