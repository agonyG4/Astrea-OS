import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root
    maxWidth: 900

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color successColor: Theme.successColor
    readonly property color errorColor: Theme.errorColor

    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + ""
    readonly property string stateJsonScript: astreaRoot + "/Core/bridge/state_json.py"
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/components.json"
    readonly property var defaultComponentConfig: ({
        desktop: true,
        topbar: true,
        island: true,
        spotlight: true,
        alttab: true,
        notifications: true
    })
    readonly property string defaultConfigJson: JSON.stringify(defaultComponentConfig, null, 4)
    readonly property var componentItems: [
        {
            key: "desktop",
            label: "Desktop Icons",
            sublabel: "Área de trabalho e atalhos renderizados pelo Astrea",
            impact: "Alto"
        },
        {
            key: "topbar",
            label: "Topbar",
            sublabel: "Barra superior, tray, rede, Bluetooth, volume e Control Center",
            impact: "Alto"
        },
        {
            key: "island",
            label: "Island",
            sublabel: "Ilha dinâmica, mídia e avisos de GameMode",
            impact: "Médio"
        },
        {
            key: "spotlight",
            label: "Spotlight",
            sublabel: "Busca rápida e atalho global do launcher",
            impact: "Médio"
        },
        {
            key: "alttab",
            label: "Alt-Tab",
            sublabel: "Switcher visual de janelas",
            impact: "Baixo"
        },
        {
            key: "notifications",
            label: "Notifications",
            sublabel: "Overlay de notificações do Astrea",
            impact: "Baixo"
        }
    ]

    property bool loading: true
    property string message: ""
    property bool messageIsError: false
    property string _configBuf: ""
    property var componentConfig: defaultComponentConfig

    function enabled(key) {
        return root.componentConfig[key] !== false
    }

    function setComponent(key, value) {
        var next = Object.assign({}, root.defaultComponentConfig, root.componentConfig)
        next[key] = value
        root.componentConfig = next
        saveConfigProc.jsonData = JSON.stringify(next, null, 4)
        saveConfigProc.command = ["python3", root.stateJsonScript, "write", root.configPath, saveConfigProc.jsonData]
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    function showMessage(text, isError) {
        root.message = text
        root.messageIsError = isError
        messageTimer.restart()
    }

    Component.onCompleted: loadConfigProc.running = true

    Process {
        id: loadConfigProc
        command: ["python3", root.stateJsonScript, "read-or-init", root.configPath, root.defaultConfigJson]
        stdout: SplitParser {
            onRead: line => root._configBuf += line
        }
        onExited: code => {
            if (code !== 0) {
                root.showMessage("Não foi possível carregar components.json", true)
                root.loading = false
                return
            }

            try {
                root.componentConfig = Object.assign({}, root.defaultComponentConfig, JSON.parse(root._configBuf || "{}"))
            } catch (error) {
                root.componentConfig = root.defaultComponentConfig
                root.showMessage("components.json inválido; usando padrão seguro", true)
            }
            root._configBuf = ""
            root.loading = false
        }
    }

    Process {
        id: saveConfigProc
        property string jsonData: ""
        command: []
        running: false
        onExited: code => {
            if (code === 0)
                root.showMessage("Components updated", false)
            else
                root.showMessage("Não foi possível salvar components.json", true)
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
            text: "COMPONENTS"
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
                model: root.loading ? [] : root.componentItems

                delegate: SettingRow {
                    required property var modelData
                    required property int index
                    label: modelData.label
                    sublabel: modelData.sublabel + " · Impacto: " + modelData.impact
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    isLast: index === root.componentItems.length - 1

                    ToggleSwitch {
                        checked: root.enabled(modelData.key)
                        onToggled: root.setComponent(modelData.key, !root.enabled(modelData.key))
                    }
                }
            }
        }
    }
}
