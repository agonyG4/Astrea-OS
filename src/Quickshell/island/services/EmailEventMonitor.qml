import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state")
    property string eventFile: stateHome + "/Astrea/island/email_event.json"
    property string lastEventId: ""

    signal eventReady(var event)

    function applyEventText(text) {
        try {
            const event = JSON.parse((text || "").trim())
            const eventId = String(event.eventId || "")
            if (event.kind !== "emailCode" || eventId === "" || eventId === root.lastEventId)
                return
            if (Number(event.expiresAt || 0) * 1000 <= Date.now())
                return
            root.lastEventId = eventId
            root.eventReady(event)
        } catch (error) {}
    }

    FileView {
        id: eventFileView
        path: root.eventFile
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyEventText(text())
    }
}
