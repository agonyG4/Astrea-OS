import Quickshell.Io
import QtQuick

Item {
    id: root

    property string commandPath: ""
    property var bars: [0, 0, 0, 0, 0, 0]
    property alias running: musicBarsProcess.running

    function stop() {
        musicBarsProcess.running = false
        bars = [0, 0, 0, 0, 0, 0]
    }

    Process {
        id: musicBarsProcess
        command: [root.commandPath]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var frame = null
                try {
                    frame = JSON.parse(data)
                } catch (error) {
                    return
                }

                if (!frame || !frame.bands || frame.bands.length < 6)
                    return

                var nextBars = []
                for (var i = 0; i < 6; i++) {
                    var value = Number(frame.bands[i])
                    if (!isFinite(value))
                        value = 0
                    nextBars.push(Math.max(0, Math.min(100, value * 100)))
                }
                root.bars = nextBars
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {}
        }
    }
}
