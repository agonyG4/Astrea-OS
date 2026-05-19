import QtQuick 2.15
import Quickshell.Io

QtObject {
    id: deviceNet

    property QtObject app
    property ListModel deviceModel: ListModel {}
    property var autoMountDeviceIds: []
    property string autoMountDeviceIdsJson: "[]"
    property string deviceOperationPath: ""
    property string deviceOperationType: ""
    property string deviceOperationTargetMountPath: ""
    property bool deviceOperationOpenAfterMount: false
    property string lastUnmountedMountPath: ""
    property string deviceError: ""
    property bool networkConnectVisible: false
    property string networkAddress: ""
    property string networkError: ""
    property bool networkConnecting: false

    function showNetworkConnectDialog() {
        networkError = ""
        if (!networkAddress)
            networkAddress = "smb://"
        networkConnectVisible = true
    }

    function hideNetworkConnectDialog() {
        if (networkConnecting)
            return
        networkConnectVisible = false
        networkError = ""
    }

    function normalizedNetworkAddress() {
        var value = (networkAddress || "").trim()
        if (!value)
            return ""
        if (value.indexOf("://") === -1)
            value = "smb://" + value
        return value
    }

    function openNetworkBrowser() {
        networkError = ""
        networkProbeProcess.command = [
            "python3",
            app.helperPath,
            "network-mount-probe",
            app.networkRootPath
        ]
        networkProbeProcess.running = false
        networkProbeProcess.running = true
    }

    function connectToNetwork() {
        var address = normalizedNetworkAddress()
        if (!address || networkConnecting)
            return

        networkError = ""
        networkConnecting = true
        networkConnectProcess.command = ["gio", "mount", address]
        networkConnectProcess.running = false
        networkConnectProcess.running = true
    }

    function loadSavedAutoMounts() {
        try {
            var parsed = JSON.parse(autoMountDeviceIdsJson || "[]")
            autoMountDeviceIds = Array.isArray(parsed) ? parsed : []
        } catch (error) {
            autoMountDeviceIds = []
            autoMountDeviceIdsJson = "[]"
        }
    }

    function saveAutoMounts() {
        autoMountDeviceIdsJson = JSON.stringify(autoMountDeviceIds)
    }

    function isDeviceAutoMount(deviceId) {
        return autoMountDeviceIds.indexOf(deviceId) !== -1
    }

    function setDeviceAutoMount(deviceId, enabled) {
        var items = autoMountDeviceIds.slice()
        var index = items.indexOf(deviceId)
        if (enabled) {
            if (index === -1)
                items.push(deviceId)
        } else if (index !== -1) {
            items.splice(index, 1)
        }
        autoMountDeviceIds = items
        saveAutoMounts()
        syncDeviceAutoMountFlags()
    }

    function toggleDeviceAutoMount(deviceId) {
        setDeviceAutoMount(deviceId, !isDeviceAutoMount(deviceId))
        if (isDeviceAutoMount(deviceId))
            ensureAutoMountDevices()
    }

    function syncDeviceAutoMountFlags() {
        for (var i = 0; i < deviceModel.count; ++i)
            deviceModel.setProperty(i, "autoMount", isDeviceAutoMount(deviceModel.get(i).id))
    }

    function replaceDeviceModel(items) {
        deviceModel.clear()
        for (var i = 0; i < items.length; ++i) {
            var item = items[i]
            item.autoMount = isDeviceAutoMount(item.id)
            item.busy = item.devicePath === deviceOperationPath
            deviceModel.append(item)
        }
    }

    function refreshDevices() {
        if (deviceListProcess.running)
            return
        deviceListProcess.command = [app.backendPath, "devices"]
        deviceListProcess.running = false
        deviceListProcess.running = true
    }

    function scheduleStartupDeviceRefresh() {
        startupDeviceRefreshTimer.restart()
    }

    function ensureAutoMountDevices() {
        if (deviceOperationProcess.running)
            return

        for (var i = 0; i < deviceModel.count; ++i) {
            var device = deviceModel.get(i)
            if (device.autoMount && !device.mounted && device.canMount && !device.busy) {
                requestMountDevice(device.devicePath, true, false)
                return
            }
        }
    }

    function requestMountDevice(devicePath, fromAutoMount, openAfterMount) {
        if (!devicePath || deviceOperationProcess.running)
            return
        deviceOperationPath = devicePath
        deviceOperationType = fromAutoMount ? "mount-auto" : "mount"
        deviceOperationTargetMountPath = ""
        deviceOperationOpenAfterMount = !!openAfterMount
        deviceError = ""
        syncDeviceBusyFlags()
        deviceOperationProcess.command = [app.backendPath, "mount", devicePath]
        deviceOperationProcess.running = false
        deviceOperationProcess.running = true
    }

    function requestUnmountDevice(devicePath, mountPath) {
        if (!devicePath || deviceOperationProcess.running)
            return
        deviceOperationPath = devicePath
        deviceOperationType = "unmount"
        deviceOperationTargetMountPath = mountPath || ""
        deviceOperationOpenAfterMount = false
        deviceError = ""
        syncDeviceBusyFlags()
        deviceOperationProcess.command = [app.backendPath, "unmount", devicePath]
        deviceOperationProcess.running = false
        deviceOperationProcess.running = true
    }

    function requestRemountDevice(devicePath, mountPath, openAfterMount) {
        if (!devicePath || deviceOperationProcess.running)
            return
        deviceOperationPath = devicePath
        deviceOperationType = "remount"
        deviceOperationTargetMountPath = mountPath || ""
        deviceOperationOpenAfterMount = !!openAfterMount
        deviceError = ""
        syncDeviceBusyFlags()
        deviceOperationProcess.command = [app.backendPath, "remount", devicePath]
        deviceOperationProcess.running = false
        deviceOperationProcess.running = true
    }

    function syncDeviceBusyFlags() {
        for (var i = 0; i < deviceModel.count; ++i)
            deviceModel.setProperty(i, "busy", deviceModel.get(i).devicePath === deviceOperationPath && deviceOperationPath !== "")
    }

    property Process networkProbeProcess: Process {
        command: []
        running: false
        stdout: StdioCollector { id: networkProbeStdout }
        onExited: function(exitCode) {
            var hasMounts = networkProbeStdout.text.trim() !== ""
            if (exitCode === 0 && hasMounts)
                app.navigateTo(app.networkRootPath)
            else
                deviceNet.showNetworkConnectDialog()
        }
    }

    property Process networkConnectProcess: Process {
        command: []
        running: false
        stdout: StdioCollector { id: networkConnectStdout }
        stderr: StdioCollector { id: networkConnectStderr }
        onExited: function(exitCode) {
            deviceNet.networkConnecting = false
            if (exitCode === 0) {
                deviceNet.networkConnectVisible = false
                deviceNet.networkError = ""
                app.navigateTo(app.networkRootPath)
                return
            }
            var errorText = networkConnectStderr.text.trim()
            if (!errorText)
                errorText = networkConnectStdout.text.trim()
            deviceNet.networkError = errorText || "Não foi possível conectar ao servidor."
        }
    }

    property Process deviceListProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: deviceListStdout
            onStreamFinished: {
                try {
                    deviceNet.replaceDeviceModel(JSON.parse(this.text))
                    deviceNet.deviceError = ""
                    deviceNet.ensureAutoMountDevices()
                } catch (error) {
                    deviceNet.deviceModel.clear()
                    deviceNet.deviceError = "Erro ao carregar dispositivos"
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && deviceListStdout.text.trim() === "") {
                deviceNet.deviceModel.clear()
                deviceNet.deviceError = "Erro ao carregar dispositivos"
            }
        }
    }

    property Process deviceOperationProcess: Process {
        command: []
        running: false
        stdout: StdioCollector { id: deviceOperationStdout }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                var response = {}
                try {
                    response = JSON.parse(deviceOperationStdout.text || "{}")
                } catch (error) {
                    response = {}
                }

                if ((deviceNet.deviceOperationType.indexOf("mount") === 0
                        || deviceNet.deviceOperationType === "remount") && response.mountPath) {
                    deviceNet.lastUnmountedMountPath = ""
                    if (deviceNet.deviceOperationOpenAfterMount)
                        app.navigateTo(response.mountPath)
                } else if (deviceNet.deviceOperationType === "unmount") {
                    deviceNet.lastUnmountedMountPath = deviceNet.deviceOperationTargetMountPath
                    if (app.currentPath && deviceNet.deviceOperationTargetMountPath
                            && app.currentPath.indexOf(deviceNet.deviceOperationTargetMountPath) === 0)
                        app.navigateTo(app.homePath)
                }

                deviceNet.deviceError = ""
            } else {
                deviceNet.deviceError = "Não foi possível "
                        + (deviceNet.deviceOperationType === "unmount" ? "desmontar" : "montar")
                        + " o dispositivo"
            }

            deviceNet.deviceOperationPath = ""
            deviceNet.deviceOperationType = ""
            deviceNet.deviceOperationTargetMountPath = ""
            deviceNet.deviceOperationOpenAfterMount = false
            deviceNet.syncDeviceBusyFlags()
            deviceNet.refreshDevices()
        }
    }

    property Timer deviceRefreshTimer: Timer {
        interval: 5000
        repeat: true
        running: false
        onTriggered: deviceNet.refreshDevices()
    }

    property Timer startupDeviceRefreshTimer: Timer {
        interval: 900
        repeat: false
        onTriggered: {
            deviceNet.refreshDevices()
            if (!deviceNet.deviceRefreshTimer.running)
                deviceNet.deviceRefreshTimer.start()
        }
    }
}
