import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool active: true
    property int pollInterval: active ? 10000 : 5000
    readonly property var throttledServices: [
        "astrea-weatherd.service"
    ]

    property string _statusBuffer: ""
    property string _serviceAction: ""
    property var _serviceQueue: []
    property bool _servicesStopped: false

    function refresh() {
        if (statusProc.running)
            return
        _statusBuffer = ""
        statusProc.running = true
    }

    function applyThrottling() {
        if (active) {
            if (!_servicesStopped) {
                _servicesStopped = true
                queueServiceAction("stop")
            }
            return
        }

        if (_servicesStopped) {
            _servicesStopped = false
            queueServiceAction("start")
        }
    }

    function queueServiceAction(action) {
        _serviceAction = action
        _serviceQueue = throttledServices.slice()
        runNextServiceAction()
    }

    function runNextServiceAction() {
        if (serviceProc.running || _serviceQueue.length === 0)
            return

        var nextQueue = _serviceQueue.slice()
        var service = nextQueue.shift()
        _serviceQueue = nextQueue
        serviceProc.command = ["systemctl", "--user", _serviceAction, service]
        serviceProc.running = true
    }

    onActiveChanged: applyThrottling()

    Component.onCompleted: {
        applyThrottling()
        refresh()
    }

    property var pollTimer: Timer {
        interval: root.pollInterval
        repeat: true
        running: true
        onIntervalChanged: restart()
        onTriggered: root.refresh()
    }

    property var statusProc: Process {
        id: statusProc
        command: ["gamemoded", "-s"]
        running: false
        stdout: SplitParser {
            onRead: data => root._statusBuffer += data
        }
        stderr: SplitParser {
            onRead: data => root._statusBuffer += data
        }
        onExited: {
            root.active = root._statusBuffer.toLowerCase().indexOf("is active") >= 0
            root._statusBuffer = ""
        }
    }

    property var serviceProc: Process {
        id: serviceProc
        command: []
        running: false
        onExited: root.runNextServiceAction()
    }
}
