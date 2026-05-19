import Quickshell.Io
import QtQuick

Item {
    id: root

    property string scriptPath: ""
    property string imagePath: ""
    property string cacheKey: ""
    property alias running: dominantColor.running

    signal colorReady(string color, string cacheKey, string imagePath)

    function start(path, key) {
        imagePath = path
        cacheKey = key || path
        dominantColor.running = false
        Qt.callLater(() => { dominantColor.running = true })
    }

    Process {
        id: dominantColor
        command: [root.scriptPath, root.imagePath]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                if (p.length !== 3)
                    return
                var r = parseInt(p[0])
                var g = parseInt(p[1])
                var b = parseInt(p[2])
                if (isNaN(r) || isNaN(g) || isNaN(b))
                    return
                root.colorReady(Qt.rgba(r / 255, g / 255, b / 255, 1).toString(), root.cacheKey, root.imagePath)
            }
        }
    }
}
