import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color errorColor: Theme.errorColor
    readonly property string fontFamily: Theme.fontFamily
    readonly property int fontSizeHero: Theme.fontSizeHeader
    readonly property int fontSizeTitle: Theme.fontSizeTitle
    readonly property int fontSizeBody: Theme.fontSizeNormal
    readonly property int fontSizeMeta: Theme.fontSizeSmall
    readonly property int fontSizeLabel: Theme.fontSizeTiny

    readonly property string scriptPath: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/Core/bridge/system/info.py"
    readonly property string logoPath: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/Assets/images/brand/astrea-logo.png"

    property bool loading: true
    property string errorMessage: ""
    property string _infoBuf: ""
    property var systemInfo: ({
        system: {
            distro: "Unknown",
            kernel: "Unknown",
            hostname: "Unknown",
            architecture: "Unknown",
            desktop: "Unknown",
            session_type: "Unknown",
            machine: "Unknown"
        },
        hardware: {
            cpu: "Unknown",
            gpu: "Unknown",
            memory_total: "Unknown",
            memory_total_bytes: 0
        }
    })

    Component.onCompleted: infoProc.running = true

    Process {
        id: infoProc
        command: ["python3", root.scriptPath]
        stdout: SplitParser {
            onRead: line => root._infoBuf += line
        }
        onExited: code => {
            if (code !== 0) {
                root.errorMessage = "Não foi possível ler as informações do sistema"
            } else {
                try {
                    root.systemInfo = JSON.parse(root._infoBuf || "{}")
                } catch (e) {
                    root.errorMessage = "Erro lendo informações do sistema: " + e
                }
            }
            root._infoBuf = ""
            root.loading = false
        }
    }

    maxWidth: 960
    scrollGap: 18

    component InfoValue: Item {
        id: infoValue
        property string label: ""
        property string value: ""
        implicitHeight: infoCol.implicitHeight
        implicitWidth: parent ? parent.width : 220

        Column {
            id: infoCol
            width: parent.width
            spacing: 5

            Text {
                text: infoValue.label
                font.family: root.fontFamily
                color: root.textSecondary
                font.pixelSize: root.fontSizeLabel
                font.weight: Font.Medium
                font.letterSpacing: Theme.trackingHeader
            }

            Text {
                width: parent.width
                text: infoValue.value
                font.family: root.fontFamily
                color: root.textPrimary
                font.pixelSize: root.fontSizeBody
                font.weight: Font.Medium
                wrapMode: Text.Wrap
            }
        }
    }

    component DetailCard: Rectangle {
        id: detailCard
        property string title: ""
        property string subtitle: ""
        default property alias cardContent: detailContent.data

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        radius: 16
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        implicitHeight: detailLayout.implicitHeight + 36

        ColumnLayout {
            id: detailLayout
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: detailCard.title
                    font.family: root.fontFamily
                    color: root.textPrimary
                    font.pixelSize: root.fontSizeTitle
                    font.weight: Font.Medium
                }

                Text {
                    visible: detailCard.subtitle !== ""
                    text: detailCard.subtitle
                    font.family: root.fontFamily
                    color: root.textSecondary
                    font.pixelSize: root.fontSizeMeta
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                id: detailContent
                Layout.fillWidth: true
                spacing: 14
            }
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
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.text.system"]) || "SYSTEM")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 14
        }

        Text {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            font.family: root.fontFamily
            color: root.errorColor
            font.pixelSize: root.fontSizeBody
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 18
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            radius: 16
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: heroLayout.implicitHeight + 36

            ColumnLayout {
                id: heroLayout
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Rectangle {
                        width: 72
                        height: 72
                        radius: 18
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: root.cardBorder

                        Image {
                            anchors.fill: parent
                            anchors.margins: 14
                            source: "file://" + root.logoPath
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "AstreaOS"
                            font.family: root.fontFamily
                            color: root.textPrimary
                            font.pixelSize: root.fontSizeMeta
                            font.weight: Font.Medium
                        }

                        Text {
                            text: root.systemInfo.system.distro || "System"
                            font.family: root.fontFamily
                            color: root.textPrimary
                            font.pixelSize: root.fontSizeHero
                            font.weight: Font.Medium
                        }

                        Text {
                            text: (root.systemInfo.system.machine || "Unknown machine") + "  •  " + (root.systemInfo.system.hostname || "Unknown host")
                            font.family: root.fontFamily
                            color: root.textSecondary
                            font.pixelSize: root.fontSizeBody
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Text {
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.text.um_retrato_rapido_do_hardware_da_sessao_e_da_ide"]) || "A quick snapshot of this device hardware, session, and identity.")
                            font.family: root.fontFamily
                            color: root.textSecondary
                            font.pixelSize: root.fontSizeMeta
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.cardBorder
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 720 ? 3 : 1
                    columnSpacing: 16
                    rowSpacing: 12

                    InfoValue {
                        Layout.fillWidth: true
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.kernel"]) || "Kernel")
                        value: root.systemInfo.system.kernel || "Unknown"
                    }

                    InfoValue {
                        Layout.fillWidth: true
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.desktop"]) || "Desktop")
                        value: root.systemInfo.system.desktop || "Unknown"
                    }

                    InfoValue {
                        Layout.fillWidth: true
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.memory"]) || "Memory")
                        value: root.systemInfo.hardware.memory_total || "Unknown"
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            columns: width >= 860 ? 2 : 1
            columnSpacing: 18
            rowSpacing: 18

            DetailCard {
                title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.title.hardware"]) || "Hardware")
                subtitle: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.subtitle.resumo_do_equipamento_detectado"]) || "Summary of detected hardware.")

                InfoValue {
                    Layout.fillWidth: true
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.machine"]) || "Machine")
                    value: root.systemInfo.system.machine || "Unknown"
                }

                InfoValue {
                    Layout.fillWidth: true
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.cpu"]) || "CPU")
                    value: root.systemInfo.hardware.cpu || "Unknown"
                }

                InfoValue {
                    Layout.fillWidth: true
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.gpu"]) || "GPU")
                    value: root.systemInfo.hardware.gpu || "Unknown"
                }

                InfoValue {
                    Layout.fillWidth: true
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.memory"]) || "Memory")
                    value: root.systemInfo.hardware.memory_total || "Unknown"
                }
            }

            DetailCard {
                title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.title.system"]) || "System")
                subtitle: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.subtitle.base_do_sistema_operacional_e_da_sessao"]) || "Operating system and session base.")

                InfoValue { Layout.fillWidth: true; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.distribution"]) || "Distribution"); value: root.systemInfo.system.distro || "Unknown" }
                InfoValue { Layout.fillWidth: true; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.kernel"]) || "Kernel"); value: root.systemInfo.system.kernel || "Unknown" }
                InfoValue { Layout.fillWidth: true; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.desktop"]) || "Desktop"); value: root.systemInfo.system.desktop || "Unknown" }
                InfoValue { Layout.fillWidth: true; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.session"]) || "Session"); value: root.systemInfo.system.session_type || "Unknown" }
            }

            DetailCard {
                title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.title.identity"]) || "Identity")
                subtitle: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["settings.system.device_arch_subtitle"]) || "Device and architecture identity.")

                InfoValue { Layout.fillWidth: true; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.hostname"]) || "Hostname"); value: root.systemInfo.system.hostname || "Unknown" }
                InfoValue { Layout.fillWidth: true; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.architecture"]) || "Architecture"); value: root.systemInfo.system.architecture || "Unknown" }
                InfoValue { Layout.fillWidth: true; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.system.label.desktop_shell"]) || "Desktop Shell"); value: root.systemInfo.system.desktop || "Unknown" }
            }
        }
    }
}
