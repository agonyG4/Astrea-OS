import Quickshell
import Quickshell.Io
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

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
    color: bgColor

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

    property var weatherData: null
    property bool loading: true
    property string errorMsg: ""
    property string weatherScript: "/home/agony/GitHub/Bench/Weather/scripts/weather.py"
    property string themeFile: "/home/agony/.local/share/Astrea/System/MAC/theme"
    property bool isDark: false

    Process {
        id: themeMonitor
        command: ["bash", "-c", "cat \"$1\"; while inotifywait -q -e modify \"$1\" 2>/dev/null; do cat \"$1\"; done", "--", themeFile]
        running: true
        stdout: SplitParser {
            onRead: data => {
                isDark = data.trim().toLowerCase() === "dark"
            }
        }
    }

readonly property color bgColor: isDark ? "#1A1A1A" : "#F5F5F7"
readonly property color surfaceColor: isDark ? "#232323" : "#FFFFFF"
readonly property color elevatedSurfaceColor: isDark ? "#2A2A2A" : "#F2F2F7"

readonly property color primaryColor: isDark ? "#F5F5F7" : "#1C1C1E"
readonly property color midColor: isDark ? "#D1D1D6" : "#2C2C2E"
readonly property color secondaryColor: isDark ? "#A1A1A6" : "#6E6E73"
readonly property color tertiaryColor: isDark ? "#7C7C80" : "#8E8E93"

readonly property color borderColor: isDark ? "#343434" : "#D9D9DE"
readonly property color subtleBorderColor: isDark ? "#2A2A2A" : "#E5E5EA"

readonly property color hoverColor: isDark ? "#2E2E2E" : "#E9E9EE"
readonly property color pressedColor: isDark ? "#383838" : "#DCDCE2"
readonly property color selectedColor: isDark ? "#2F3E55" : "#DCEBFF"

readonly property color accentColor: isDark ? "#4D8DFF" : "#007AFF"
readonly property color accentHoverColor: isDark ? "#6AA2FF" : "#248AFF"
readonly property color accentPressedColor: isDark ? "#3C78E6" : "#0062CC"

readonly property color successColor: isDark ? "#32D74B" : "#28C840"
readonly property color warningColor: isDark ? "#FF9F0A" : "#FF9500"
readonly property color errorColor: isDark ? "#FF453A" : "#FF3B30"

readonly property color shadowColor: isDark ? "#000000" : "#00000018"
readonly property color overlayColor: isDark ? "#00000099" : "#00000033"
readonly property color disabledColor: isDark ? "#5A5A5F" : "#B8B8BE"

    component TextLabel: Label {
        font.family: "SF Pro Text"
        antialiasing: true
        color: primaryColor
    }

    component DisplayLabel: Label {
        font.family: "SF Pro Display"
        antialiasing: true
        color: primaryColor
    }

    function weatherIcon(desc) {
        if (!desc) return "🌡️"
        var d = desc.toLowerCase()
        if (d.includes("trovoada"))              return "⛈️"
        if (d.includes("granizo"))               return "🌨️"
        if (d.includes("pancadas fortes"))       return "🌧️"
        if (d.includes("pancadas"))              return "🌦️"
        if (d.includes("neve"))                  return "❄️"
        if (d.includes("garoa"))                 return "🌦️"
        if (d.includes("chuva forte"))           return "🌧️"
        if (d.includes("chuva"))                 return "🌧️"
        if (d.includes("névoa"))                 return "🌫️"
        if (d.includes("nublado"))               return "☁️"
        if (d.includes("parcialmente"))          return "⛅"
        if (d.includes("principalmente"))        return "🌤️"
        if (d.includes("limpo"))                 return "☀️"
        if (d.includes("céu"))                   return "☀️"
        if (d.includes("ensolarado"))            return "☀️"
        return "🌡️"
    }

    function refreshWeather() {
        loading = true
        errorMsg = ""
        weatherProc.running = true
    }

    Process {
        id: weatherProc
        command: ["/usr/bin/env", "python3", weatherScript, "get", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    weatherData = JSON.parse(this.text)
                    errorMsg = ""
                } catch(e) {
                    weatherData = null
                    errorMsg = "Erro ao parsear JSON"
                }
                loading = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    errorMsg = this.text.trim()
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && errorMsg === "")
                errorMsg = "Falha ao atualizar o clima"
            loading = false
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: refreshWeather()
    }

    Rectangle {
        anchors.fill: parent
        color: bgColor
        radius: 24

        ColumnLayout {
            anchors.centerIn: parent
            visible: loading
            spacing: 12
            DisplayLabel {
                Layout.alignment: Qt.AlignHCenter
                text: "⛅"
                font.pixelSize: 48
            }
            TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: "Carregando..."
                font.pixelSize: 14
                color: secondaryColor
            }
        }

        TextLabel {
            anchors.centerIn: parent
            visible: !loading && errorMsg !== ""
            text: errorMsg
            color: "red"
            font.pixelSize: 14
        }

        Flickable {
            id: mainFlick
            anchors.fill: parent
            anchors.topMargin: 0
            anchors.bottomMargin: 0
            contentHeight: mainLayout.implicitHeight + 64 // 32 margins top/bottom
            clip: true
            visible: !loading && errorMsg === "" && weatherData !== null
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: mainLayout
                width: parent.width - 64 // 32 margins each side
                anchors.top: parent.top
                anchors.topMargin: 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                DisplayLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: weatherData ? weatherData.city : ""
                    font.pixelSize: 22
                    topPadding: 24
                }

                DisplayLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: weatherData ? weatherData.temp : "--"
                    font.pixelSize: 70
                    font.weight: Font.Light
                    lineHeight: 1.0
                }

                TextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: weatherData ? weatherData.condition : ""
                    font.pixelSize: 18
                    color: midColor
                    topPadding: 4
                }

                TextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: weatherData ? "Sensação térmica de " + weatherData.feels_like : ""
                    font.pixelSize: 13
                    color: secondaryColor
                    topPadding: 6
                    bottomPadding: 16
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: borderColor
                }

                Item { implicitHeight: 16 }

                // Hourly Forecast
                ListView {
                    id: hourlyList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    orientation: ListView.Horizontal
                    spacing: 24
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: weatherData ? weatherData.hourly.slice(0, 12) : []
                    
                    delegate: Item {
                        width: 50
                        height: 100
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8
                            TextLabel {
                                text: index === 0 ? "Agora" : modelData.time
                                font.pixelSize: 13
                                color: secondaryColor
                                Layout.alignment: Qt.AlignHCenter
                            }
                            DisplayLabel {
                                text: weatherIcon(modelData.cond)
                                font.pixelSize: 22
                                Layout.alignment: Qt.AlignHCenter
                            }
                            TextLabel {
                                text: modelData.temp + "°"
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: primaryColor
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                Item { implicitHeight: 16 }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: borderColor
                }

                Item { implicitHeight: 8 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: weatherData ? weatherData.weekly.slice(0, 8) : []
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 12
                                Layout.bottomMargin: 12

                                TextLabel {
                                    text: index === 0 ? "Hoje" : modelData.day
                                    font.pixelSize: 15
                                    Layout.fillWidth: true
                                }

                                DisplayLabel {
                                    text: weatherIcon(modelData.cond)
                                    font.pixelSize: 18
                                }

                                Item { implicitWidth: 12 }

                                TextLabel {
                                    text: modelData.hi
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    Layout.preferredWidth: 40
                                    horizontalAlignment: Text.AlignRight
                                }

                                TextLabel {
                                    text: modelData.lo
                                    font.pixelSize: 15
                                    color: secondaryColor
                                    Layout.preferredWidth: 40
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: subtleBorderColor
                                visible: index < (weatherData ? weatherData.weekly.length - 1 : 0)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
