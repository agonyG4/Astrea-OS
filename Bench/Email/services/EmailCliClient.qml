import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: client

    readonly property string defaultCliPath: Quickshell.env("HOME") + "/GitHub/Bench/Email/bin/astrea-email"

    property string cliPath: defaultCliPath
    property bool configured: false
    property bool authenticated: false
    property bool busy: emailProc.running
    property string account: ""
    property string statusMessage: "Checking email backend"
    property string lastError: ""
    property string credentialsPath: ""
    property string tokenPath: ""
    property string tokenState: "missing"
    property string _action: ""
    property string _buffer: ""
    property string _errorBuffer: ""

    signal statusReady(var payload)
    signal authReady(var payload)
    signal messagesReady(var payload)
    signal messageReady(var payload)
    signal sendReady(var payload)
    signal modifyReady(var payload)
    signal failed(string action, string message)

    function refreshStatus() {
        runCommand("status", ["status"])
    }

    function authenticate() {
        runCommand("auth", ["auth"])
    }

    function list(folder, messageFilter, query, pageToken, limit, forceRefresh, cacheOnly) {
        const args = [
            "list",
            "--folder", folder,
            "--filter", messageFilter,
            "--query", query || "",
            "--limit", String(limit || 100)
        ]
        if (pageToken && pageToken !== "")
            args.push("--page-token", pageToken)
        if (forceRefresh)
            args.push("--refresh")
        if (cacheOnly)
            args.push("--cache-only")
        runCommand("list", args)
    }

    function send(to, subject, body) {
        runCommand("send", ["send", "--to", to, "--subject", subject, "--body", body || ""])
    }

    function modify(messageId, action) {
        runCommand("modify", ["modify", "--id", messageId, "--action", action])
    }

    function get(messageId, loadImages) {
        const args = ["get", "--id", messageId]
        if (loadImages)
            args.push("--images")
        runCommand("get", args)
    }

    function runCommand(action, args) {
        if (emailProc.running) {
            lastError = "Email backend is busy"
            failed(action, lastError)
            return
        }

        _action = action
        _buffer = ""
        _errorBuffer = ""
        lastError = ""
        emailProc.command = [cliPath].concat(args)
        emailProc.running = true
    }

    function updateStatus(payload) {
        configured = !!payload.configured
        authenticated = !!payload.authenticated
        account = payload.account || ""
        credentialsPath = payload.credentialsPath || ""
        tokenPath = payload.tokenPath || ""
        tokenState = payload.tokenState || "missing"
        statusMessage = payload.message || (authenticated ? "Gmail ready" : "Connect Gmail")
    }

    function dispatch(payload) {
        if (_action === "status") {
            updateStatus(payload)
            statusReady(payload)
        } else if (_action === "auth") {
            updateStatus(payload)
            authReady(payload)
        } else if (_action === "list") {
            messagesReady(payload)
        } else if (_action === "get") {
            messageReady(payload)
        } else if (_action === "send") {
            sendReady(payload)
        } else if (_action === "modify") {
            modifyReady(payload)
        }
    }

    Process {
        id: emailProc
        command: []
        running: false

        stdout: SplitParser {
            onRead: data => client._buffer += data
        }

        stderr: SplitParser {
            onRead: data => client._errorBuffer += data
        }

        onExited: exitCode => {
            var payload = ({ ok: false, message: client._errorBuffer || client._buffer || "Email backend command failed" })
            try {
                if (client._buffer.trim() !== "")
                    payload = JSON.parse(client._buffer)
            } catch (e) {
                payload = ({ ok: false, message: client._buffer || String(e) })
            }

            if (exitCode !== 0 || !payload.ok) {
                client.lastError = payload.message || client._errorBuffer || "Email backend command failed"
                if (client._action === "status")
                    client.updateStatus(payload)
                client.failed(client._action, client.lastError)
            } else {
                client.dispatch(payload)
            }

            client._buffer = ""
            client._errorBuffer = ""
        }
    }

    Component.onCompleted: refreshStatus()
}
