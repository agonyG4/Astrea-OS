import Quickshell
import QtQuick 2.15
import QtQuick.Layouts 1.15
import "AstreaComponents" as UI
import "components/common" as WeatherCommon
import "components/sections" as Sections
import "state" as State

FloatingWindow {
    id: root
    title: "WeatherApp"
    implicitWidth: 430
    implicitHeight: 740
    visible: true
    color: "#151517"
    property var selectedDay: null
    property var selectedAlert: null
    property bool settingsOpen: false
    readonly property var colors: ({
        primary: UI.Theme.textPrimary,
        secondary: UI.Theme.textSecondary,
        tertiary: UI.Theme.textTertiary,
        error: UI.Theme.errorColor
    })

    function rainHours(day) {
        if (!day || !day.hours)
            return []

        var items = []
        for (var i = 0; i < day.hours.length; i++) {
            if ((day.hours[i].rain || 0) > 0)
                items.push(day.hours[i])
        }
        return items
    }

    Behavior on color {
        ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    State.WeatherState {
        id: weather
    }

    Rectangle {
        anchors.fill: parent
        color: "#151517"
        radius: 0

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Sections.LoadingState {
            visible: weather.loading
            colors: root.colors
        }

        Sections.ErrorState {
            visible: !weather.loading && weather.errorMsg !== ""
            text: weather.errorMsg
            colors: root.colors
        }

        Flickable {
            id: mainFlick
            anchors.fill: parent
            contentHeight: mainLayout.implicitHeight + 64
            clip: true
            visible: !weather.loading && weather.errorMsg === "" && weather.weatherData !== null
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: mainLayout
                width: parent.width - 36
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Sections.CurrentSummary {
                    weatherData: weather.weatherData
                    colors: root.colors
                }

                Sections.WeatherAlerts {
                    weatherData: weather.weatherData
                    colors: root.colors
                    onAlertSelected: function(alert) {
                        root.selectedAlert = alert
                    }
                }

                Sections.HourlyForecast {
                    weatherData: weather.weatherData
                    colors: root.colors
                }

                Sections.WeeklyForecast {
                    weatherData: weather.weatherData
                    colors: root.colors
                    onDaySelected: function(day) {
                        root.selectedDay = day
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Sections.AirQuality {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        weatherData: weather.weatherData
                        colors: root.colors
                    }
                    
                    Sections.TemperatureTrend {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        weatherData: weather.weatherData
                        colors: root.colors
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Sections.FeelsLike {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        weatherData: weather.weatherData
                        colors: root.colors
                    }
                    
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        Rectangle {
            id: settingsButton
            width: 34
            height: 34
            radius: 17
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            z: 45
            color: settingsButtonArea.containsMouse ? "#3A3A40" : "#2B2B30"
            border.color: "#45454C"
            border.width: 1

            UI.TextLabel {
                anchors.centerIn: parent
                text: "⚙"
                font.pixelSize: 16
                textColor: UI.Theme.textPrimary
            }

            MouseArea {
                id: settingsButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsOpen = true
            }
        }

        Item {
            anchors.fill: parent
            visible: root.settingsOpen
            z: 70

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.36
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.settingsOpen = false
            }

            Rectangle {
                width: parent.width
                height: 210
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                radius: 26
                color: UI.Theme.cardBg
                border.color: "#45454C"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        UI.DisplayLabel {
                            Layout.fillWidth: true
                            text: "Settings"
                            font.pixelSize: UI.Theme.fontSizeIconLarge
                            font.weight: 500
                            textColor: UI.Theme.textPrimary
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: closeSettingsArea.containsMouse ? "#424248" : "#36363C"

                            UI.TextLabel {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 18
                                textColor: UI.Theme.textSecondary
                            }

                            MouseArea {
                                id: closeSettingsArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.settingsOpen = false
                            }
                        }
                    }

                    UI.Divider {
                        lineColor: "#4A4A50"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            UI.TextLabel {
                                text: "Notifications"
                                font.pixelSize: UI.Theme.fontSizeTitle
                                font.weight: 500
                                textColor: UI.Theme.textPrimary
                            }

                            UI.TextLabel {
                                text: "INMET alerts"
                                font.pixelSize: UI.Theme.fontSizeLarge
                                textColor: UI.Theme.textTertiary
                            }
                        }

                        UI.ToggleSwitch {
                            checked: weather.alertNotificationsEnabled
                            onToggled: weather.setAlertNotificationsEnabled(!weather.alertNotificationsEnabled)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.selectedDay !== null
            z: 50

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.36
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.selectedDay = null
            }

            Rectangle {
                id: detailSheet
                width: parent.width
                height: 650
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                radius: 26
                color: UI.Theme.cardBg
                border.color: "#45454C"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        WeatherCommon.WeatherIcon {
                            condition: root.selectedDay ? root.selectedDay.cond : ""
                            iconSize: 38
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            UI.DisplayLabel {
                                text: root.selectedDay ? root.selectedDay.day : ""
                                font.pixelSize: UI.Theme.fontSizeIconLarge
                                font.weight: 500
                                textColor: UI.Theme.textPrimary
                            }

                            UI.TextLabel {
                                text: root.selectedDay ? root.selectedDay.cond : ""
                                font.pixelSize: UI.Theme.fontSizeLarge
                                font.weight: 400
                                textColor: "#C9CAD2"
                            }
                        }

                        UI.TextLabel {
                            text: root.selectedDay ? root.selectedDay.hi + "° / " + root.selectedDay.lo + "°" : ""
                            font.pixelSize: 18
                            font.weight: 500
                            textColor: UI.Theme.textPrimary
                        }
                    }

                    UI.Divider {
                        lineColor: "#4A4A50"
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 10

                        UI.TextLabel {
                            text: root.selectedDay ? "Chuva " + root.selectedDay.rain + "%" : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            textColor: "#F2F2F7"
                            Layout.fillWidth: true
                        }

                        UI.TextLabel {
                            text: root.selectedDay ? "UV " + root.selectedDay.uv : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            horizontalAlignment: Text.AlignRight
                            textColor: "#F2F2F7"
                            Layout.fillWidth: true
                        }

                        UI.TextLabel {
                            text: root.selectedDay ? "Nascer " + root.selectedDay.sunrise : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            textColor: "#C9CAD2"
                            Layout.fillWidth: true
                        }

                        UI.TextLabel {
                            text: root.selectedDay ? "Pôr " + root.selectedDay.sunset : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            horizontalAlignment: Text.AlignRight
                            textColor: "#C9CAD2"
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#424248"
                    }

                    UI.TextLabel {
                        text: "Horários com chance de chuva"
                        font.pixelSize: 12
                        font.weight: 500
                        textColor: UI.Theme.textTertiary
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: root.rainHours(root.selectedDay)

                        delegate: RowLayout {
                            width: ListView.view.width
                            spacing: 10

                            UI.TextLabel {
                                text: modelData.time
                                font.pixelSize: UI.Theme.fontSizeLarge
                                font.weight: 500
                                textColor: UI.Theme.textPrimary
                                Layout.preferredWidth: 48
                            }

                            WeatherCommon.WeatherIcon {
                                condition: modelData.cond
                                isoTime: modelData.iso_time || ""
                                iconSize: 22
                            }

                            UI.TextLabel {
                                text: modelData.cond
                                font.pixelSize: UI.Theme.fontSizeLarge
                                elide: Text.ElideRight
                                textColor: "#C9CAD2"
                                Layout.fillWidth: true
                            }

                            UI.TextLabel {
                                text: modelData.rain + "%"
                                font.pixelSize: UI.Theme.fontSizeLarge
                                font.weight: 500
                                horizontalAlignment: Text.AlignRight
                                textColor: "#9CC7FF"
                                Layout.preferredWidth: 40
                            }
                        }
                    }

                    UI.TextLabel {
                        Layout.fillWidth: true
                        visible: root.rainHours(root.selectedDay).length === 0
                        text: "Sem horários de chuva nos dados disponíveis."
                        font.pixelSize: UI.Theme.fontSizeLarge
                        horizontalAlignment: Text.AlignHCenter
                        textColor: "#C9CAD2"
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.selectedAlert !== null
            z: 60

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.36
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.selectedAlert = null
            }

            Rectangle {
                width: parent.width
                height: Math.min(parent.height - 80, Math.max(260, alertContent.implicitHeight + 36))
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                radius: 26
                color: UI.Theme.cardBg
                border.color: root.selectedAlert ? (root.selectedAlert.color || "#F96602") : "#F96602"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 18
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: alertContent.implicitHeight

                    ColumnLayout {
                        id: alertContent
                        width: parent.width
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 46
                                radius: 6
                                color: root.selectedAlert ? (root.selectedAlert.color || "#F96602") : "#F96602"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                UI.TextLabel {
                                    text: "INMET"
                                    font.pixelSize: 10
                                    font.weight: 600
                                    textColor: root.selectedAlert ? (root.selectedAlert.color || "#F96602") : "#F96602"
                                }

                                UI.DisplayLabel {
                                    text: root.selectedAlert ? (root.selectedAlert.title || "Aviso meteorológico") : ""
                                    font.pixelSize: UI.Theme.fontSizeIconLarge
                                    font.weight: 500
                                    textColor: UI.Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                UI.TextLabel {
                                    text: root.selectedAlert ? (root.selectedAlert.severity || "") : ""
                                    font.pixelSize: UI.Theme.fontSizeLarge
                                    textColor: "#C9CAD2"
                                }
                            }
                        }

                        UI.Divider {
                            lineColor: "#4A4A50"
                        }

                        UI.TextLabel {
                            Layout.fillWidth: true
                            text: root.selectedAlert && root.selectedAlert.start && root.selectedAlert.end
                                ? "Válido de " + root.selectedAlert.start + " até " + root.selectedAlert.end
                                : ""
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            font.pixelSize: 12
                            textColor: "#C9CAD2"
                        }

                        UI.TextLabel {
                            text: "Riscos"
                            font.pixelSize: 12
                            font.weight: 500
                            textColor: UI.Theme.textTertiary
                        }

                        Repeater {
                            model: root.selectedAlert && root.selectedAlert.risks ? root.selectedAlert.risks : []

                            delegate: UI.TextLabel {
                                Layout.fillWidth: true
                                text: modelData
                                wrapMode: Text.WordWrap
                                font.pixelSize: UI.Theme.fontSizeLarge
                                lineHeight: 1.14
                                textColor: "#F2F2F7"
                            }
                        }

                        UI.TextLabel {
                            text: "O que fazer"
                            font.pixelSize: 12
                            font.weight: 500
                            textColor: UI.Theme.textTertiary
                        }

                        Repeater {
                            model: root.selectedAlert && root.selectedAlert.instructions ? root.selectedAlert.instructions : []

                            delegate: UI.TextLabel {
                                Layout.fillWidth: true
                                text: "• " + modelData
                                wrapMode: Text.WordWrap
                                font.pixelSize: UI.Theme.fontSizeLarge
                                lineHeight: 1.12
                                textColor: "#DDDDE4"
                            }
                        }
                    }
                }
            }
        }
    }
}
