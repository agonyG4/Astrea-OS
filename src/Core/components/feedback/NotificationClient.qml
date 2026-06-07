import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string appName: "Astrea"
    property string appIcon: ""
    property bool appForeground: false
    property string presentation: "banner"
    property string foregroundPresentation: "list"
    property string urgency: "normal"
    property string interruptionLevel: "active"
    property int expireTimeout: -1
    property string notifyPath: Quickshell.env("ASTREA_NOTIFY_CLI") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea/bin/astrea-notify")
    property bool busy: notifyProc.running || queue.length > 0
    property var queue: []
    property string _buffer: ""
    property string _errorBuffer: ""

    signal delivered(var payload)
    signal failed(string message)

    function value(payload, key, fallback) {
        if (!payload || payload[key] === undefined || payload[key] === null || payload[key] === "")
            return fallback
        return payload[key]
    }

    function presentationFor(payload) {
        if (payload && payload.presentation !== undefined && payload.presentation !== "")
            return payload.presentation
        if (root.appForeground && !(payload && payload.forceBanner))
            return root.foregroundPresentation
        return root.presentation
    }

    function notify(payload) {
        const item = payload || ({})
        const summary = root.value(item, "summary", qsTr("Notification"))
        const args = [
            "--app", root.value(item, "appName", root.appName),
            "--summary", summary,
            "--body", root.value(item, "body", ""),
            "--icon", root.value(item, "appIcon", root.appIcon),
            "--presentation", root.presentationFor(item),
            "--urgency", root.value(item, "urgency", root.urgency),
            "--interruption-level", root.value(item, "interruptionLevel", root.interruptionLevel),
            "--expire-timeout", String(root.value(item, "expireTimeout", root.expireTimeout))
        ]

        const eventId = root.value(item, "eventId", "")
        if (eventId !== "")
            args.push("--event-id", eventId)
        const threadId = root.value(item, "threadId", "")
        if (threadId !== "")
            args.push("--thread-id", threadId)
        const collapseKey = root.value(item, "collapseKey", "")
        if (collapseKey !== "")
            args.push("--collapse-key", collapseKey)

        root.enqueue(args)
    }

    function enqueue(args) {
        const nextQueue = root.queue.slice()
        nextQueue.push(args)
        root.queue = nextQueue
        root.startNext()
    }

    function startNext() {
        if (notifyProc.running || root.queue.length === 0)
            return

        const nextQueue = root.queue.slice()
        const args = nextQueue.shift()
        root.queue = nextQueue
        root._buffer = ""
        root._errorBuffer = ""
        notifyProc.command = [root.notifyPath].concat(args)
        notifyProc.running = true
    }

    Process {
        id: notifyProc
        command: []
        running: false

        stdout: SplitParser {
            onRead: data => root._buffer += data
        }

        stderr: SplitParser {
            onRead: data => root._errorBuffer += data
        }

        onExited: exitCode => {
            let payload = ({ ok: false, message: root._errorBuffer || root._buffer || qsTr("Notification failed") })
            try {
                if (root._buffer.trim() !== "")
                    payload = JSON.parse(root._buffer)
            } catch (error) {
                payload = ({ ok: false, message: root._buffer || String(error) })
            }

            if (exitCode === 0 && payload.ok)
                root.delivered(payload)
            else
                root.failed(payload.message || root._errorBuffer || qsTr("Notification failed"))

            root.startNext()
        }
    }
}
