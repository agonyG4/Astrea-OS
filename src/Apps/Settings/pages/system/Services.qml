import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"

ScrollPage {
    id: root
    maxWidth: 900

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color successColor: Theme.successColor
    readonly property color errorColor: Theme.errorColor

    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")
    readonly property string servicesScript: astreaRoot + "/Core/bridge/system/services.py"

    property bool loading: true
    property string message: ""
    property bool messageIsError: false
    property string busyKey: ""
    property string _loadBuf: ""
    property string _actionBuf: ""
    property var services: []

    function stateLabel(service) {
        if (!service.available)
            return "Not installed"
        if (root.busyKey === service.key)
            return "Applying"
        if (service.state === "on-demand")
            return "On demand"
        if (service.state === "embedded")
            return "Shell managed"
        if (service.state === "active")
            return "Running"
        if (service.state === "inactive")
            return "Stopped"
        return service.enabled ? "Enabled" : "Disabled"
    }

    function rowSubtitle(service) {
        var parts = [
            service.group || "Astrea",
            root.stateLabel(service),
            "Managed by: " + (service.managed_by || "systemd --user"),
            "Impact: " + (service.impact || "Unknown")
        ]
        if (service.activation === "systemd")
            parts.push("Unit: " + service.unit)
        if (service.critical)
            parts.push("Critical")
        if (!service.toggleable)
            parts.push("Read-only")
        return parts.join(" · ")
    }

    function showMessage(text, isError) {
        root.message = text
        root.messageIsError = isError
        if (!isError)
            messageTimer.restart()
    }

    function applyPayload(payload) {
        root.services = payload && payload.services ? payload.services : []
    }

    function loadServices() {
        if (loadProc.running)
            return
        root._loadBuf = ""
        loadProc.running = true
    }

    function updateLocalEnabled(key, enabled) {
        var next = root.services.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].key !== key)
                continue
            var item = Object.assign({}, next[i])
            item.enabled = enabled
            item.enabled_state = enabled ? "enabled" : "disabled"
            item.state = "unknown"
            next[i] = item
            break
        }
        root.services = next
    }

    function setService(service, enabled) {
        if (actionProc.running || !service.toggleable)
            return
        root.busyKey = service.key
        root.message = ""
        root.updateLocalEnabled(service.key, enabled)
        root._actionBuf = ""
        actionProc.command = ["python3", root.servicesScript, "set", service.key, enabled ? "true" : "false"]
        actionProc.running = true
    }

    Component.onCompleted: root.loadServices()

    Process {
        id: loadProc
        command: ["python3", root.servicesScript, "list"]
        running: false
        stdout: SplitParser { onRead: data => root._loadBuf += data }
        onExited: code => {
            if (code === 0) {
                try {
                    root.applyPayload(JSON.parse(root._loadBuf || "{}"))
                    root.message = ""
                } catch (error) {
                    root.showMessage("Could not parse Astrea services.", true)
                }
            } else {
                root.showMessage("Could not read Astrea services.", true)
            }
            root._loadBuf = ""
            root.loading = false
        }
    }

    Process {
        id: actionProc
        command: []
        running: false
        stdout: SplitParser { onRead: data => root._actionBuf += data }
        stderr: SplitParser { onRead: data => root._actionBuf += data }
        onExited: code => {
            var ok = code === 0
            var detail = ""
            try {
                var payload = JSON.parse(root._actionBuf || "{}")
                root.applyPayload(payload)
                ok = ok && payload.ok !== false
                detail = payload.error || payload.detail || ""
            } catch (error) {
                detail = String(error)
            }
            root.busyKey = ""
            root._actionBuf = ""
            root.showMessage(ok ? "Service updated." : ("Could not update service. " + detail), !ok)
        }
    }

    Timer {
        id: messageTimer
        interval: 1800
        repeat: false
        onTriggered: root.message = ""
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.loading
        width: 48
        height: 48

        BusyIndicator {
            anchors.fill: parent
            running: root.loading
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 0
        visible: !root.loading

        SectionHeader {
            text: "ASTREA SERVICES"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.message !== ""
            text: root.message
            color: root.messageIsError ? root.errorColor : root.successColor
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 16
        }

        FormCard {
            Layout.bottomMargin: 22

            Repeater {
                model: root.services

                delegate: SettingRow {
                    required property var modelData
                    required property int index
                    label: modelData.label
                    sublabel: root.rowSubtitle(modelData)
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: Theme.cardBorder
                    isLast: index === root.services.length - 1

                    ToggleSwitch {
                        checked: modelData.enabled
                        enabled: modelData.toggleable && root.busyKey === ""
                        onToggled: target => root.setService(modelData, target)
                    }
                }
            }
        }
    }
}
