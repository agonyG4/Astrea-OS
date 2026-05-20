import QtQuick
import Qt5Compat.GraphicalEffects
import "." as Components

Item {
    id: root

    property string imagePath: ""
    property int imageVersion: 0
    property string fallbackText: "?"
    property color fallbackColor: Qt.rgba(Components.Theme.accent.r, Components.Theme.accent.g, Components.Theme.accent.b, 0.18)
    property color fallbackTextColor: Components.Theme.accent
    property string fallbackFontFamily: ""
    property real fallbackFontPixelSize: Math.round(Math.min(width, height) * 0.42)
    property int fallbackFontWeight: Font.Medium
    property bool smooth: true
    property bool mipmap: true
    property bool asynchronous: true
    property real sourceScale: 2
    property real maskMargin: 0
    property color borderColor: "transparent"
    property real borderWidth: 0
    readonly property string resolvedSource: imagePath.length > 0
        ? "file://" + imagePath + "?v=" + imageVersion
        : ""
    readonly property bool hasLoadedImage: avatarImg.status === Image.Ready

    implicitWidth: 48
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.fallbackColor
        antialiasing: true
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(width * 4, height * 4)
        layer.samples: 8

        Text {
            anchors.centerIn: parent
            text: root.fallbackText
            font.family: root.fallbackFontFamily
            font.pixelSize: root.fallbackFontPixelSize
            font.weight: root.fallbackFontWeight
            color: root.fallbackTextColor
        }
    }

    Image {
        id: avatarImg
        anchors.fill: parent
        source: root.resolvedSource
        fillMode: Image.PreserveAspectCrop
        smooth: root.smooth
        mipmap: root.mipmap
        visible: false
        asynchronous: root.asynchronous
        sourceSize: Qt.size(width * root.sourceScale, height * root.sourceScale)
        layer.enabled: true
    }

    Rectangle {
        id: avatarMask
        anchors.fill: parent
        radius: width / 2
        antialiasing: true
        visible: false
    }

    OpacityMask {
        anchors.fill: avatarMaskFrame
        source: avatarImg
        maskSource: avatarMask
        antialiasing: true
        visible: root.hasLoadedImage
    }

    Item {
        id: avatarMaskFrame
        anchors.fill: parent
        anchors.margins: root.maskMargin
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: root.borderWidth
        border.color: root.borderColor
        border.pixelAligned: false
        antialiasing: true
        visible: root.borderWidth > 0
    }
}
