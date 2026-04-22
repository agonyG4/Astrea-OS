import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "file:/home/agony/.local/share/Astrea/Core/components"

ScrollPage {
    id: root
    maxWidth: 900

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor
    readonly property color successColor: Theme.successColor
    readonly property color warningColor: Theme.warningColor
    readonly property string heroArtPath: (Quickshell.env("HOME") || "") + "/.local/share/Astrea/Assets/images/brand/astrea-logo.png"
    readonly property string installedVersion: "Astrea 1"
    readonly property string updateSize: root.selectedChannel === 0 ? "2.4 GB" : "2.6 GB"
    readonly property string updateName: root.selectedChannel === 0 ? "Astrea 1" : "Astrea 1 Beta"

    component ActionButton: Rectangle {
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitHeight: 32
        implicitWidth: actionLabel.implicitWidth + 26
        radius: 10
        color: primary ? root.accent : Qt.rgba(1, 1, 1, 0.06)
        border.width: primary ? 0 : 1
        border.color: root.cardBorder
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: parent.label
            color: primary ? "#ffffff" : root.textPrimary
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/system/system.json"
    readonly property var channelOptions: ["Stable", "Alpha"]
    readonly property var channelValues: ["stable", "alpha"]

    property bool loading: true
    property string errorMessage: ""
    property string saveMessage: ""
    property string _configBuf: ""
    property int selectedChannel: 0
    property var updateConfig: ({
        auto_updater: false,
        channel: "stable"
    })

    function channelIndexForValue(value) {
        const idx = root.channelValues.indexOf(value)
        return idx >= 0 ? idx : 0
    }

    function saveConfig(showMessage) {
        saveConfigProc.jsonData = JSON.stringify(root.updateConfig, null, 4)
        saveConfigProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; cat <<'EOF' > \"$1\"\n" + saveConfigProc.jsonData + "\nEOF\n",
            "--", root.configPath]
        saveConfigProc.showMessage = showMessage
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    function mutateConfig(mutator, showMessage) {
        var next = JSON.parse(JSON.stringify(root.updateConfig))
        mutator(next)
        root.updateConfig = next
        root.selectedChannel = root.channelIndexForValue(next.channel)
        saveConfig(showMessage)
    }

    Component.onCompleted: loadConfigProc.running = true

    Process {
        id: loadConfigProc
        command: ["bash", "-c",
            "FILE=\"$1\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "if [ ! -f \"$FILE\" ]; then " +
            "  printf '%s\n' '{' " +
            "    '  \"auto_updater\": false,' " +
            "    '  \"channel\": \"stable\"' " +
            "  '}' > \"$FILE\"; " +
            "fi; " +
            "cat \"$FILE\"",
            "--", root.configPath]
        stdout: SplitParser {
            onRead: line => root._configBuf += line
        }
        onExited: {
            try {
                const cfg = JSON.parse(root._configBuf || "{}")
                root.updateConfig = Object.assign({}, root.updateConfig, cfg)
                root.selectedChannel = root.channelIndexForValue(root.updateConfig.channel)
            } catch (e) {
                root.errorMessage = "Erro lendo system.json: " + e
            }
            root._configBuf = ""
            root.loading = false
        }
    }

    Process {
        id: saveConfigProc
        property string jsonData: ""
        property bool showMessage: false
        command: []
        onExited: {
            if (showMessage)
                root.saveMessage = ""
        }
    }

    Timer {
        id: saveMessageTimer
        interval: 1800
        repeat: false
        onTriggered: root.saveMessage = ""
    }

    component ToggleSwitch: Rectangle {
        id: toggle
        width: 36
        height: 20
        radius: 10
        implicitWidth: 36
        implicitHeight: 20
        property bool checked: false
        signal toggled()
        color: checked ? root.accent : Qt.rgba(1, 1, 1, 0.18)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    component StatusBadge: Rectangle {
        property string label: ""
        property color tone: Qt.rgba(1, 1, 1, 0.14)
        radius: 9
        color: tone
        implicitHeight: 24
        implicitWidth: badgeText.implicitWidth + 18

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: parent.label
            color: "#ffffff"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
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
            text: "SOFTWARE UPDATE"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: root.errorMessage !== "" ? root.errorColor : root.successColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 18
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            radius: 16
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: heroCol.implicitHeight + 32

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 0
            }

            ColumnLayout {
                id: heroCol
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Rectangle {
                        implicitWidth: 92
                        implicitHeight: 92
                        radius: 24
                        color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.06)
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 14
                            source: "file://" + root.heroArtPath
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root.updateName
                            color: root.textPrimary
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: root.updateSize
                            color: root.textSecondary
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        Text {
                            text: "A página salva as preferências de update agora e aplica esse comportamento quando o updater real estiver disponível."
                            color: root.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                        ActionButton {
                            label: "Atualizar"
                            primary: true
                        }

                        ActionButton {
                            label: "Atualizar à noite"
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 14
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: updateCol.implicitHeight + 32

            ColumnLayout {
                id: updateCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 0

                SettingRow {
                    label: "Auto updater"
                    sublabel: "Salva a preferência para quando o updater real estiver conectado."
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    ToggleSwitch {
                        checked: !!root.updateConfig.auto_updater
                        onToggled: root.mutateConfig(function(next) {
                            next.auto_updater = !next.auto_updater
                        }, true)
                    }
                }

                SettingRow {
                    label: "Release channel"
                    sublabel: "Stable prioriza previsibilidade; Alpha recebe novidades mais cedo."
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    SelectButton {
                        implicitWidth: 140
                        label: root.channelOptions[root.selectedChannel]
                        options: root.channelOptions
                        selectedIndex: root.selectedChannel
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        popupBg: root.popupBg
                        onSelected: index => {
                            root.selectedChannel = index
                            root.mutateConfig(function(next) {
                                next.channel = root.channelValues[index]
                            }, true)
                        }
                    }
                }

                SettingRow {
                    label: "Current state"
                    sublabel: "Sem backend conectado no momento, então nenhum update é realmente baixado ou aplicado."
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    isLast: true

                    StatusBadge {
                        label: "Unavailable"
                        tone: Qt.rgba(root.warningColor.r, root.warningColor.g, root.warningColor.b, 0.28)
                    }
                }
            }
        }

    }
}
