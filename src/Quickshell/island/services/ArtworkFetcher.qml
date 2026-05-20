import Quickshell.Io
import QtQuick

Item {
    id: root

    property string scriptPath: ""
    property string url: ""
    property alias running: fetchArt.running

    signal fetched(string path, string url)

    function fetch(nextUrl) {
        if (fetchArt.running && root.url === nextUrl)
            return

        fetchArt.running = false
        Qt.callLater(() => {
            root.url = nextUrl
            fetchArt.running = true
        })
    }

    Process {
        id: fetchArt
        command: ["python3", root.scriptPath, root.url]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (!path)
                    return
                root.fetched(path, root.url)
            }
        }
    }
}
