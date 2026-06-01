import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var componentSettings: null
    property bool gameModeActive: false

    readonly property bool desktopEnabled: !componentSettings || componentSettings.desktop
    readonly property bool topbarEnabled: !componentSettings || componentSettings.topbar
    readonly property bool islandEnabled: !componentSettings || componentSettings.island
    readonly property bool notificationsEnabled: !componentSettings || componentSettings.notifications
    readonly property bool musicMonitoringNeeded: topbarEnabled || islandEnabled

    property bool _statusShouldRun: true
    property bool _statusKnown: false
    property bool _desktopCleanupQueued: false
    property bool _musicCleanupQueued: false
    property bool _notificationCleanupQueued: false
    property string _cleanupKind: ""
    property var _cleanupQueue: []

    function reconcile() {
        const nextStatusShouldRun = root.topbarEnabled
        if (!root._statusKnown || nextStatusShouldRun !== root._statusShouldRun) {
            root._statusShouldRun = nextStatusShouldRun
            root._statusKnown = true
            statusServiceProc.command = ["systemctl", "--user", nextStatusShouldRun ? "start" : "stop", "astrea-status.service"]
            statusServiceProc.running = false
            statusServiceProc.running = true
        }

        if (!root.desktopEnabled && !root._desktopCleanupQueued) {
            root._desktopCleanupQueued = true
            queueCleanup("desktop", [
                ["pkill", "-f", "app_index.py.*--watch-signature"],
                ["pkill", "-f", "app_index.py.*--json"]
            ])
        } else if (root.desktopEnabled) {
            root._desktopCleanupQueued = false
        }

        if (!root.musicMonitoringNeeded && !root._musicCleanupQueued) {
            root._musicCleanupQueued = true
            queueCleanup("music", [
                ["pkill", "-f", "music_bars.sh"],
                ["pkill", "-f", "player_monitor.sh"]
            ])
        } else if (root.musicMonitoringNeeded) {
            root._musicCleanupQueued = false
        }

        if (!root.notificationsEnabled && !root._notificationCleanupQueued) {
            root._notificationCleanupQueued = true
            queueCleanup("notifications", [
                ["pkill", "-f", "notification_daemon.py"]
            ])
        } else if (root.notificationsEnabled) {
            root._notificationCleanupQueued = false
        }
    }

    function queueCleanup(kind, commands) {
        if (cleanupProc.running) {
            for (let i = 0; i < commands.length; i++)
                root._cleanupQueue.push(commands[i])
            return
        }

        root._cleanupKind = kind
        root._cleanupQueue = commands.slice()
        runNextCleanup()
    }

    function runNextCleanup() {
        if (cleanupProc.running || root._cleanupQueue.length === 0)
            return

        const nextQueue = root._cleanupQueue.slice()
        cleanupProc.command = nextQueue.shift()
        root._cleanupQueue = nextQueue
        cleanupProc.running = true
    }

    Component.onCompleted: reconcile()
    onDesktopEnabledChanged: reconcile()
    onTopbarEnabledChanged: reconcile()
    onIslandEnabledChanged: reconcile()
    onNotificationsEnabledChanged: reconcile()
    onGameModeActiveChanged: reconcile()

    Process {
        id: statusServiceProc
        command: []
        running: false
    }

    Process {
        id: cleanupProc
        command: []
        running: false
        onExited: root.runNextCleanup()
    }
}
