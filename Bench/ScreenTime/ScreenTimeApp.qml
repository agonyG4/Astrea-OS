import Quickshell
import QtQuick 2.15
import QtQuick.Layouts 1.15
import "components/common" as Common
import "components/sections" as Sections
import "state" as State
import "."

FloatingWindow {
    id: root
    title: "ScreenTime"
    implicitWidth: 430
    implicitHeight: 720
    maximized: false
    fullscreen: false
    visible: true
    color: Theme.bg

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    onMaximizedChanged: {
        if (maximized)
            maximized = false
    }

    onFullscreenChanged: {
        if (fullscreen)
            fullscreen = false
    }

    State.ScreenTimeState {
        id: screenTime
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            visible: screenTime.loading

            Item { Layout.fillHeight: true }

            Common.DisplayLabel {
                Layout.alignment: Qt.AlignHCenter
                text: "ScreenTime"
                font.pixelSize: Theme.fontLarge
                font.weight: 600
                textColor: Theme.textPrimary
            }

            Common.TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: "Carregando"
                font.pixelSize: Theme.fontRegular
                textColor: Theme.textTertiary
            }

            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            visible: !screenTime.loading && screenTime.errorMsg !== "" && screenTime.screenData === null

            Item { Layout.fillHeight: true }

            Common.DisplayLabel {
                Layout.alignment: Qt.AlignHCenter
                text: "ScreenTime"
                font.pixelSize: Theme.fontLarge
                font.weight: 600
                textColor: Theme.textPrimary
            }

            Common.TextLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: screenTime.errorMsg
                font.pixelSize: Theme.fontRegular
                textColor: Theme.red
            }

            Item { Layout.fillHeight: true }
        }

        Flickable {
            anchors.fill: parent
            contentHeight: mainLayout.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: screenTime.screenData !== null

            ColumnLayout {
                id: mainLayout
                width: parent.width - 36
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Common.DisplayLabel {
                            Layout.fillWidth: true
                            text: "ScreenTime"
                            font.pixelSize: Theme.fontLarge
                            font.weight: 600
                            textColor: Theme.textPrimary
                        }

                        Common.TextLabel {
                            Layout.fillWidth: true
                            text: screenTime.screenData ? "Atualizado " + screenTime.screenData.generated_at : ""
                            font.pixelSize: Theme.fontSmall
                            textColor: Theme.textTertiary
                            elide: Text.ElideRight
                        }
                    }
                }

                Sections.SummaryCard {
                    summaryData: screenTime.screenData
                }

                Sections.UsageList {
                    title: "Categorias"
                    rows: screenTime.screenData && screenTime.screenData.day ? screenTime.screenData.day.categories : []
                    totalSeconds: screenTime.screenData && screenTime.screenData.day ? screenTime.screenData.day.seconds : 0
                    accentColor: Theme.accent
                }

                Sections.UsageList {
                    title: "Apps"
                    rows: screenTime.screenData && screenTime.screenData.day ? screenTime.screenData.day.apps : []
                    totalSeconds: screenTime.screenData && screenTime.screenData.day ? screenTime.screenData.day.seconds : 0
                    accentColor: Theme.green
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: footer.implicitHeight + 24
                    radius: Theme.cardRadius
                    color: Theme.cardBg
                    opacity: 0.92
                    border.color: "#3A3A40"
                    border.width: 1

                    ColumnLayout {
                        id: footer
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Common.TextLabel {
                            Layout.fillWidth: true
                            text: "Saude"
                            font.pixelSize: Theme.fontSmall
                            font.weight: 700
                            textColor: Theme.textTertiary
                        }

                        Common.Divider {}

                        Common.TextLabel {
                            Layout.fillWidth: true
                            text: screenTime.screenData && screenTime.screenData.health ? "PID " + (screenTime.screenData.health.pid || "-") + " - amostras " + screenTime.screenData.sample_count + " - erros " + screenTime.screenData.error_count : ""
                            font.pixelSize: Theme.fontRegular
                            textColor: Theme.textSecondary
                            elide: Text.ElideRight
                        }

                        Common.TextLabel {
                            Layout.fillWidth: true
                            visible: screenTime.screenData && screenTime.screenData.health && screenTime.screenData.health.last_error !== ""
                            text: screenTime.screenData && screenTime.screenData.health ? screenTime.screenData.health.last_error : ""
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSmall
                            textColor: Theme.amber
                        }
                    }
                }
            }
        }
    }
}
