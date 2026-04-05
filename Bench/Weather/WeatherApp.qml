import Quickshell
import Quickshell.Io
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

FloatingWindow {
    title: "WeatherApp"
    implicitWidth: 450
    implicitHeight: 700
    visible: true

    property var weatherData: null
    property bool loading: true
    property string errorMsg: ""

    component TextLabel: Label {
        font.family: "SF Pro Text"
        antialiasing: true
    }

    component DisplayLabel: Label {
        font.family: "SF Pro Display"
        antialiasing: true
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
        return "🌡️"
    }

    Process {
        id: weatherProc
        command: ["/bin/python", "/home/agony/GitHub/Bench/Weather/scripts/weather.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    weatherData = JSON.parse(this.text)
                    errorMsg = ""
                } catch(e) {
                    errorMsg = "Erro ao parsear JSON"
                }
                loading = false
            }
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: {
            loading = true
            weatherProc.running = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
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
                color: "#888888"
            }
        }

        TextLabel {
            anchors.centerIn: parent
            visible: !loading && errorMsg !== ""
            text: errorMsg
            color: "red"
            font.pixelSize: 14
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            visible: !loading && errorMsg === "" && weatherData !== null
            spacing: 0

            DisplayLabel {
                Layout.alignment: Qt.AlignHCenter
                text: weatherData ? weatherData.city : ""
                font.pixelSize: 22
                color: "#111111"
                topPadding: 24
            }

            DisplayLabel {
                Layout.alignment: Qt.AlignHCenter
                text: weatherData ? weatherData.temp : "--"
                font.pixelSize: 70
                font.weight: Font.Light
                color: "#111111"
                lineHeight: 1.0
            }

            TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: weatherData ? weatherData.condition : ""
                font.pixelSize: 18
                color: "#333333"
                topPadding: 4
            }

            TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: weatherData ? "Sensação térmica de " + weatherData.feels_like : ""
                font.pixelSize: 13
                color: "#888888"
                topPadding: 6
                bottomPadding: 32
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#eeeeee"
            }

            Item { implicitHeight: 24 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: weatherData ? weatherData.weekly.slice(0, 10) : []
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
                                color: "#111111"
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
                                color: "#111111"
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }

                            TextLabel {
                                text: modelData.lo
                                font.pixelSize: 15
                                color: "#aaaaaa"
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#f0f0f0"
                            visible: index < (weatherData ? weatherData.weekly.length - 1 : 0)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
