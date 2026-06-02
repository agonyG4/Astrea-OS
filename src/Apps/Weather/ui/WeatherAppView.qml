import Quickshell
import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../AstreaComponents" as UI
import "components/common" as WeatherCommon
import "components/sections" as Sections
import "state" as State
import "../AstreaI18n" as AstreaI18n

FloatingWindow {
    id: root
    title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.title.weatherapp"]) || "WeatherApp")
    implicitWidth: 430
    implicitHeight: 740
    visible: true
    color: UI.Theme.windowBackground
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

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    Behavior on color {
        ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    onSettingsOpenChanged: {
        if (settingsOpen)
            cityInput.text = weather.city || ""
    }

    State.WeatherState {
        id: weather
    }

    Rectangle {
        id: appSurface
        anchors.fill: parent
        color: UI.Theme.windowBackground
        radius: 0

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Item {
            id: contentSurface
            anchors.fill: parent

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
                    width: parent.width - 32
                    anchors.top: parent.top
                    anchors.topMargin: 16
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
                color: settingsButtonArea.containsMouse ? UI.Theme.cardBorder : UI.Theme.cardBg
                border.color: UI.Theme.cardBorder
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
        }

        Item {
            anchors.fill: parent
            visible: root.settingsOpen
            z: 70

            Rectangle {
                anchors.fill: parent
                color: "transparent"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.settingsOpen = false
            }

            Rectangle {
                width: parent.width
                height: 342
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                radius: 26
                color: UI.Theme.cardBg
                opacity: 1
                border.color: UI.Theme.cardBorder
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
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.settings"]) || "Settings")
                            font.pixelSize: UI.Theme.fontSizeIconLarge
                            font.weight: 500
                            textColor: UI.Theme.textPrimary
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: closeSettingsArea.containsMouse ? UI.Theme.cardBorder : UI.Theme.cardBg

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
                        lineColor: UI.Theme.cardBorder
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        UI.TextLabel {
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.location"]) || "Location")
                            font.pixelSize: UI.Theme.fontSizeTitle
                            font.weight: 500
                            textColor: UI.Theme.textPrimary
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.045)
                                border.width: 1
                                border.color: cityInput.activeFocus ? UI.Theme.accent : UI.Theme.cardBorder

                                UI.TextLabel {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: cityInput.text.length === 0
                                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.city_country"]) || "Automatic location")
                                    font.pixelSize: UI.Theme.fontSizeLarge
                                    textColor: UI.Theme.textTertiary
                                }

                                TextInput {
                                    id: cityInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: weather.city
                                    color: UI.Theme.textPrimary
                                    selectionColor: UI.Theme.accent
                                    selectedTextColor: "#ffffff"
                                    font.pixelSize: UI.Theme.fontSizeLarge
                                    enabled: !weather.settingsBusy
                                    Keys.onReturnPressed: weather.setCity(text)
                                    Keys.onEnterPressed: weather.setCity(text)
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 74
                                Layout.preferredHeight: 38
                                radius: 10
                                color: weather.settingsBusy
                                    ? Qt.rgba(1, 1, 1, 0.06)
                                    : saveCityArea.containsMouse ? Qt.lighter(UI.Theme.accent, 1.12) : UI.Theme.accent
                                opacity: weather.settingsBusy ? 0.65 : 1

                                UI.TextLabel {
                                    anchors.centerIn: parent
                                    text: weather.settingsBusy
                                        ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.saving"]) || "Saving")
                                        : ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.save"]) || "Save")
                                    font.pixelSize: UI.Theme.fontSizeLarge
                                    font.weight: 600
                                    textColor: "#ffffff"
                                }

                                MouseArea {
                                    id: saveCityArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !weather.settingsBusy
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: weather.setCity(cityInput.text)
                                }
                            }
                        }

                        UI.TextLabel {
                            Layout.fillWidth: true
                            visible: weather.settingsError.length > 0
                            text: weather.settingsError
                            font.pixelSize: 12
                            textColor: UI.Theme.errorColor
                            wrapMode: Text.WordWrap
                        }
                    }

                    UI.Divider {
                        lineColor: UI.Theme.cardBorder
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            UI.TextLabel {
                                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.notifications"]) || "Notifications")
                                font.pixelSize: UI.Theme.fontSizeTitle
                                font.weight: 500
                                textColor: UI.Theme.textPrimary
                            }

                            UI.TextLabel {
                                text: weather.countryCode === "BR"
                                    ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.inmet_alerts"]) || "INMET alerts")
                                    : ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.weather_alerts"]) || "Weather alerts")
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
                color: "transparent"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.selectedDay = null
            }

            Rectangle {
                id: detailSheet
                property real dragOffset: 0

                function settleDrag() {
                    if (dragOffset > 110) {
                        root.selectedDay = null
                        dragOffset = 0
                    } else {
                        dragOffset = 0
                    }
                }

                width: parent.width
                height: 650
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -dragOffset
                radius: 26
                color: UI.Theme.cardBg
                opacity: 1
                border.color: UI.Theme.cardBorder
                border.width: 1

                Behavior on anchors.bottomMargin {
                    enabled: !detailDragArea.pressed
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

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
                                textColor: UI.Theme.textSecondary
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
                        lineColor: UI.Theme.cardBorder
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 10

                        UI.TextLabel {
                            text: root.selectedDay ? root.t("apps.weather.ui.weather_app_view.text.rain_percent", "Rain {percent}%", {
                                percent: root.selectedDay.rain
                            }) : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            textColor: UI.Theme.textPrimary
                            Layout.fillWidth: true
                        }

                        UI.TextLabel {
                            text: root.selectedDay ? root.t("apps.weather.ui.weather_app_view.text.uv_index", "UV {value}", {
                                value: root.selectedDay.uv
                            }) : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            horizontalAlignment: Text.AlignRight
                            textColor: UI.Theme.textPrimary
                            Layout.fillWidth: true
                        }

                        UI.TextLabel {
                            text: root.selectedDay ? root.t("apps.weather.ui.weather_app_view.text.sunrise_time", "Sunrise {time}", {
                                time: root.selectedDay.sunrise
                            }) : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            textColor: UI.Theme.textSecondary
                            Layout.fillWidth: true
                        }

                        UI.TextLabel {
                            text: root.selectedDay ? root.t("apps.weather.ui.weather_app_view.text.sunset_time", "Sunset {time}", {
                                time: root.selectedDay.sunset
                            }) : ""
                            font.pixelSize: UI.Theme.fontSizeLarge
                            horizontalAlignment: Text.AlignRight
                            textColor: UI.Theme.textSecondary
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: UI.Theme.cardBorder
                    }

                    UI.TextLabel {
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.horarios_com_chance_de_chuva"]) || "Times with chance of rain")
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
                                textColor: UI.Theme.textSecondary
                                Layout.fillWidth: true
                            }

                            UI.TextLabel {
                                text: modelData.rain + "%"
                                font.pixelSize: UI.Theme.fontSizeLarge
                                font.weight: 500
                                horizontalAlignment: Text.AlignRight
                                textColor: UI.Theme.accent
                                Layout.preferredWidth: 40
                            }
                        }
                    }

                    UI.TextLabel {
                        Layout.fillWidth: true
                        visible: root.rainHours(root.selectedDay).length === 0
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.sem_horarios_de_chuva_nos_dados_disponaveis"]) || "No rain times in the available data.")
                        font.pixelSize: UI.Theme.fontSizeLarge
                        horizontalAlignment: Text.AlignHCenter
                        textColor: UI.Theme.textSecondary
                    }
                }

                Rectangle {
                    id: detailGrabber
                    width: 42
                    height: 5
                    radius: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    color: UI.Theme.textTertiary
                    opacity: detailDragArea.pressed ? 0.95 : 0.65
                    z: 8
                }

                MouseArea {
                    id: detailDragArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 96
                    z: 9
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property real pressRootY: 0

                    onPressed: function(mouse) {
                        pressRootY = mapToItem(contentSurface, mouse.x, mouse.y).y
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed)
                            detailSheet.dragOffset = Math.max(0, mapToItem(contentSurface, mouse.x, mouse.y).y - pressRootY)
                    }

                    onReleased: detailSheet.settleDrag()
                    onCanceled: detailSheet.settleDrag()
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.selectedAlert !== null
            z: 60

            Rectangle {
                anchors.fill: parent
                color: "transparent"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.selectedAlert = null
            }

            Rectangle {
                id: alertSheet
                property real dragOffset: 0

                function settleDrag() {
                    if (dragOffset > 96) {
                        root.selectedAlert = null
                        dragOffset = 0
                    } else {
                        dragOffset = 0
                    }
                }

                width: parent.width
                height: Math.min(parent.height - 80, Math.max(260, alertContent.implicitHeight + 36))
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -dragOffset
                radius: 26
                color: UI.Theme.cardBg
                opacity: 1
                border.color: root.selectedAlert ? (root.selectedAlert.color || "#F96602") : "#F96602"
                border.width: 1

                Behavior on anchors.bottomMargin {
                    enabled: !alertDragArea.pressed
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

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
                                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.inmet"]) || "INMET")
                                    font.pixelSize: 10
                                    font.weight: 600
                                    textColor: root.selectedAlert ? (root.selectedAlert.color || "#F96602") : "#F96602"
                                }

                                UI.DisplayLabel {
                                    text: root.selectedAlert ? (root.selectedAlert.title || root.t("apps.weather.ui.weather_app_view.text.weather_alert", "Weather alert")) : ""
                                    font.pixelSize: UI.Theme.fontSizeIconLarge
                                    font.weight: 500
                                    textColor: UI.Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                UI.TextLabel {
                                    text: root.selectedAlert ? (root.selectedAlert.severity || "") : ""
                                    font.pixelSize: UI.Theme.fontSizeLarge
                                    textColor: UI.Theme.textSecondary
                                }
                            }
                        }

                        UI.Divider {
                            lineColor: UI.Theme.cardBorder
                        }

                        UI.TextLabel {
                            Layout.fillWidth: true
                            text: root.selectedAlert && root.selectedAlert.start && root.selectedAlert.end
                                ? root.t("apps.weather.ui.weather_app_view.text.valid_from_to", "Valid from {start} to {end}", {
                                    start: root.selectedAlert.start,
                                    end: root.selectedAlert.end
                                })
                                : ""
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            font.pixelSize: 12
                            textColor: UI.Theme.textSecondary
                        }

                        UI.TextLabel {
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.riscos"]) || "Risks")
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
                                textColor: UI.Theme.textPrimary
                            }
                        }

                        UI.TextLabel {
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.weather_app_view.text.o_que_fazer"]) || "What to do")
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
                                textColor: UI.Theme.textSecondary
                            }
                        }
                    }
                }

                Rectangle {
                    width: 42
                    height: 5
                    radius: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    color: UI.Theme.textTertiary
                    opacity: alertDragArea.pressed ? 0.95 : 0.65
                    z: 8
                }

                MouseArea {
                    id: alertDragArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 88
                    z: 9
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property real pressRootY: 0

                    onPressed: function(mouse) {
                        pressRootY = mapToItem(contentSurface, mouse.x, mouse.y).y
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed)
                            alertSheet.dragOffset = Math.max(0, mapToItem(contentSurface, mouse.x, mouse.y).y - pressRootY)
                    }

                    onReleased: alertSheet.settleDrag()
                    onCanceled: alertSheet.settleDrag()
                }
            }
        }
    }
}
