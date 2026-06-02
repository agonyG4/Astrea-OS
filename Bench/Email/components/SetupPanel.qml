import QtQuick
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Rectangle {
    id: panel

    property bool configured: false
    property bool authenticated: false
    property bool busy: false
    property string credentialsPath: ""
    property string tokenPath: ""
    property string account: ""
    property string statusMessage: ""
    property color softSurface: Astrea.Theme.cardBg
    signal connectRequested()
    signal refreshRequested()
    signal detailsRequested()

    radius: Astrea.Theme.cardRadius
    color: Astrea.Theme.cardBg
    border.width: 1
    border.color: Astrea.Theme.cardBorder
    clip: true

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: Astrea.Theme.spacingXLarge
        }
        spacing: Astrea.Theme.spacingLarge

        Item { Layout.fillHeight: true }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 520
            spacing: Astrea.Theme.spacingLarge

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 62
                Layout.preferredHeight: 62
                radius: 20
                color: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.28)

                Text {
                    anchors.centerIn: parent
                    text: "\uf0e0"
                    color: Astrea.Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 28
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Astrea.DisplayLabel {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: panel.authenticated ? "Gmail connected" : "Connect Gmail"
                    textColor: Astrea.Theme.textPrimary
                    font.pixelSize: Astrea.Theme.fontSizeHeader
                    font.weight: Astrea.Theme.fontWeightDemiBold
                }

                Astrea.TextLabel {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: panel.authenticated
                        ? (panel.account || "Ready to sync mail")
                        : (panel.configured ? "Authenticate to load your mailbox." : "Add the OAuth client JSON before syncing mail.")
                    textColor: Astrea.Theme.textSecondary
                    font.pixelSize: Astrea.Theme.fontSizeNormal
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: Astrea.Theme.controlRadius + 4
                color: panel.softSurface
                border.width: 1
                border.color: Astrea.Theme.cardBorder
                implicitHeight: steps.implicitHeight + 24

                ColumnLayout {
                    id: steps
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14
                        rightMargin: 14
                    }
                    spacing: 10

                    SetupRow {
                        label: "OAuth client"
                        value: panel.configured ? "Found" : panel.credentialsPath
                        active: panel.configured
                    }

                    SetupRow {
                        label: "Authentication"
                        value: panel.authenticated ? "Connected" : "Not connected"
                        active: panel.authenticated
                    }

                    SetupRow {
                        label: "Token store"
                        value: panel.tokenPath
                        active: panel.authenticated
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Astrea.Theme.spacing

                Astrea.Button {
                    text: panel.configured ? "Connect Gmail" : "Show path"
                    iconText: panel.configured ? "\uf0e0" : "\uf05a"
                    iconFontFamily: "JetBrainsMono Nerd Font"
                    primary: panel.configured
                    enabled: !panel.busy
                    onClicked: panel.configured ? panel.connectRequested() : panel.detailsRequested()
                }

                Astrea.Button {
                    text: "Refresh"
                    iconText: "\uf01e"
                    iconFontFamily: "JetBrainsMono Nerd Font"
                    flat: true
                    enabled: !panel.busy
                    onClicked: panel.refreshRequested()
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    component SetupRow: RowLayout {
        property string label: ""
        property string value: ""
        property bool active: false

        spacing: 10

        Rectangle {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            radius: 11
            color: active ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.20) : Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: active ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.34) : Astrea.Theme.cardBorder

            Text {
                anchors.centerIn: parent
                text: active ? "\uf00c" : "\uf111"
                color: active ? Astrea.Theme.accent : Astrea.Theme.textTertiary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: active ? 10 : 7
            }
        }

        Astrea.TextLabel {
            Layout.preferredWidth: 118
            text: parent.label
            textColor: Astrea.Theme.textPrimary
            font.pixelSize: Astrea.Theme.fontSizeSmall
            font.weight: Astrea.Theme.fontWeightDemiBold
            elide: Text.ElideRight
        }

        Astrea.TextLabel {
            Layout.fillWidth: true
            text: parent.value
            textColor: Astrea.Theme.textSecondary
            font.pixelSize: Astrea.Theme.fontSizeSmall
            elide: Text.ElideMiddle
        }
    }
}
