import Quickshell.Io
import QtQuick

Item {
    id: root

    property string statePath: ""
    readonly property int maxRenderedNotifications: 8
    readonly property int maxHistoryNotifications: 50
    property alias model: notificationModel
    property alias count: notificationModel.count
    property alias historyModel: notificationHistoryModel
    property alias historyCount: notificationHistoryModel.count

    function modelIndexFor(notificationId) {
        for (let index = 0; index < notificationModel.count; index++) {
            if (notificationModel.get(index).notificationId === notificationId)
                return index
        }
        return -1
    }

    function historyIndexFor(notificationId) {
        for (let index = 0; index < notificationHistoryModel.count; index++) {
            if (notificationHistoryModel.get(index).notificationId === notificationId)
                return index
        }
        return -1
    }

    function normalizedNotification(item) {
        return {
            notificationId: item.notificationId || item.id || 0,
            appName: item.appName || "Application",
            appIcon: item.appIcon || "",
            summary: item.summary || "Notification",
            body: item.body || "",
            urgency: item.urgency || 1,
            createdAt: item.createdAt || ""
        }
    }

    function removeFromModel(targetModel, notificationId) {
        for (let index = targetModel.count - 1; index >= 0; index--) {
            if (targetModel.get(index).notificationId === notificationId)
                targetModel.remove(index)
        }
    }

    function syncNotifications(items) {
        const seen = {}
        const liveItems = (items || []).slice(-root.maxRenderedNotifications)

        for (const item of liveItems) {
            const notification = normalizedNotification(item)
            seen[notification.notificationId] = true

            const index = modelIndexFor(notification.notificationId)
            if (index >= 0)
                notificationModel.set(index, notification)
            else
                notificationModel.append(notification)
        }

        for (let index = notificationModel.count - 1; index >= 0; index--) {
            const currentId = notificationModel.get(index).notificationId
            if (!seen[currentId])
                notificationModel.remove(index)
        }

        while (notificationModel.count > root.maxRenderedNotifications)
            notificationModel.remove(0)
    }

    function syncHistory(items) {
        const seen = {}
        let targetIndex = 0
        const historyItems = (items || []).slice(-root.maxHistoryNotifications)
        for (let index = historyItems.length - 1; index >= 0; index--) {
            const notification = normalizedNotification(historyItems[index])
            if (!notification.notificationId)
                continue
            seen[notification.notificationId] = true

            const existingIndex = historyIndexFor(notification.notificationId)
            if (existingIndex >= 0) {
                notificationHistoryModel.set(existingIndex, notification)
                if (existingIndex !== targetIndex)
                    notificationHistoryModel.move(existingIndex, targetIndex, 1)
            } else {
                notificationHistoryModel.insert(targetIndex, notification)
            }
            targetIndex += 1
        }

        for (let index = notificationHistoryModel.count - 1; index >= 0; index--) {
            const currentId = notificationHistoryModel.get(index).notificationId
            if (!seen[currentId])
                notificationHistoryModel.remove(index)
        }

        while (notificationHistoryModel.count > root.maxHistoryNotifications)
            notificationHistoryModel.remove(notificationHistoryModel.count - 1)
    }

    function closeNotification(notificationId) {
        closeProc.command = [
            "gdbus",
            "call",
            "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.CloseNotification",
            String(notificationId)
        ]
        closeProc.running = false
        closeProc.running = true
    }

    function clearHistoryItem(notificationId) {
        removeFromModel(notificationHistoryModel, notificationId)
        removeFromModel(notificationModel, notificationId)
        historyProc.command = [
            "gdbus",
            "call",
            "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.ClearHistoryItem",
            String(notificationId)
        ]
        historyProc.running = false
        historyProc.running = true
    }

    function clearHistory() {
        notificationHistoryModel.clear()
        notificationModel.clear()
        historyProc.command = [
            "gdbus",
            "call",
            "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.ClearHistory"
        ]
        historyProc.running = false
        historyProc.running = true
    }

    function loadState() {
        try {
            const payload = JSON.parse(stateFile.text())
            root.syncNotifications(payload.notifications || [])
            root.syncHistory(payload.history || payload.notifications || [])
        } catch (error) {
        }
    }

    Component.onCompleted: loadState()

    ListModel {
        id: notificationModel
    }

    ListModel {
        id: notificationHistoryModel
    }

    Process {
        id: closeProc
        command: []
        running: false
    }

    Process {
        id: historyProc
        command: []
        running: false
    }

    Timer {
        id: stateReloadDebounce
        interval: 150
        repeat: false
        onTriggered: stateFile.reload()
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: stateReloadDebounce.restart()
        onLoaded: root.loadState()
    }
}
