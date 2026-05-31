import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var controller: null
    property color textColor: "#66FFFFFF"
    property string fontFamily: "SF Pro Display"

    Layout.maximumWidth: 68
    Layout.alignment: Qt.AlignVCenter
    spacing: 1
    visible: controller !== null && controller.weatherEnabled

    Image {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignVCenter
        source: root.controller ? root.controller.weatherIconSource : ""
        sourceSize: Qt.size(40, 40)
        visible: root.controller !== null && root.controller.weatherReady
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        opacity: 0.78
    }

    Text {
        text: "○"
        visible: root.controller === null || !root.controller.weatherReady
        font.pixelSize: 18
        color: root.textColor
        Layout.alignment: Qt.AlignVCenter
    }

    Text {
        Layout.maximumWidth: 46
        text: root.controller && root.controller.weatherReady ? root.controller.weatherTemp + "°" : "--°"
        font.family: root.fontFamily
        font.pixelSize: 18
        font.weight: Font.Medium
        color: root.textColor
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
