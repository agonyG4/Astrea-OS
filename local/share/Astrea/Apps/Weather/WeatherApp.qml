import Quickshell
import QtQuick 2.15
import QtQuick.Layouts 1.15
import "components/common" as Common
import "components/sections" as Sections
import "state" as State

FloatingWindow {
    id: root
    title: "WeatherApp"
    implicitWidth: 450
    implicitHeight: 700
    minimumSize: Qt.size(implicitWidth, implicitHeight)
    maximumSize: Qt.size(implicitWidth, implicitHeight)
    maximized: false
    fullscreen: false
    visible: true
    color: theme.bgColor

    Behavior on color {
        ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

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

    State.ThemeState {
        id: theme
    }

    State.WeatherState {
        id: weather
    }

    Rectangle {
        anchors.fill: parent
        color: theme.bgColor
        radius: 24

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Sections.LoadingState {
            visible: weather.loading
            colors: theme.colors
        }

        Sections.ErrorState {
            visible: !weather.loading && weather.errorMsg !== ""
            text: weather.errorMsg
            colors: theme.colors
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
                width: parent.width - 64
                anchors.top: parent.top
                anchors.topMargin: 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Sections.CurrentSummary {
                    weatherData: weather.weatherData
                    colors: theme.colors
                }

                Common.Divider {
                    lineColor: theme.borderColor
                }

                Item { implicitHeight: 16 }

                Sections.HourlyForecast {
                    weatherData: weather.weatherData
                    colors: theme.colors
                }

                Item { implicitHeight: 16 }

                Common.Divider {
                    lineColor: theme.borderColor
                }

                Item { implicitHeight: 8 }

                Sections.WeeklyForecast {
                    weatherData: weather.weatherData
                    colors: theme.colors
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
