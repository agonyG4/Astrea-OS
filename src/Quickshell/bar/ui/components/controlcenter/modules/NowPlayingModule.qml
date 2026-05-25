import QtQuick
import Qt5Compat.GraphicalEffects
import "../../../.."

Rectangle {
    id: module

    property var control: null

    readonly property string title: control ? control.musicTitle : "Nada tocando"
    readonly property string artist: control ? control.musicArtist : "Spotify"
    readonly property string artSource: control ? control.musicArt : ""
    readonly property bool playing: control ? control.musicPlaying : false
    readonly property bool active: control ? control.hasMusic : false

    radius: Theme.radiusLarge
    color: Theme.background
    border.width: 1
    border.color: active ? Theme.barBorderHover : Theme.border

    Behavior on border.color { ColorAnimation { duration: Theme.animationStandard } }

    Rectangle {
        id: nowArt
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingLarge
        width: 52
        height: 52
        radius: Theme.tileRadius
        clip: true
        color: Theme.surface

        Rectangle {
            id: nowArtMask
            anchors.fill: parent
            radius: Theme.tileRadius
            visible: false
        }

        Image {
            anchors.fill: parent
            source: module.artSource
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            cache: false
            asynchronous: true
            visible: module.artSource !== ""
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: nowArtMask }
        }

        Text {
            anchors.centerIn: parent
            visible: module.artSource === ""
            text: "󰝚"
            color: Theme.shellIconMain
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIconLarge }
        }
    }

    Column {
        anchors.left: nowArt.right
        anchors.right: nowControls.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingLarge
        anchors.rightMargin: Theme.spacing
        spacing: 2

        Text {
            width: parent.width
            text: module.title
            color: Theme.shellTextActive
            elide: Text.ElideRight
            maximumLineCount: 1
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.DemiBold }
        }

        Text {
            width: parent.width
            text: module.artist
            color: Theme.shellTextSecondary
            opacity: Theme.opacityEmphasis
            elide: Text.ElideRight
            maximumLineCount: 1
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.Medium }
        }
    }

    Row {
        id: nowControls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spacingLarge
        spacing: Theme.spacingMicro

        MediaButton {
            icon: "󰒮"
            enabled: module.active
            onClicked: if (module.control) module.control.previousTrack()
        }

        MediaButton {
            icon: module.playing ? "󰏤" : "󰐊"
            enabled: module.active
            primary: true
            onClicked: if (module.control) module.control.playPause()
        }

        MediaButton {
            icon: "󰒭"
            enabled: module.active
            onClicked: if (module.control) module.control.nextTrack()
        }
    }
}
