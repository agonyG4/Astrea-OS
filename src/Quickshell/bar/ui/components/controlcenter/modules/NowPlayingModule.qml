import QtQuick
import "../../../.."
import "../../../../../AstreaI18n" as AstreaI18n

Rectangle {
    id: module

    property var control: null

    readonly property string title: control ? control.musicTitle : AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.media.nothing_playing", "Nothing playing")
    readonly property string artist: control ? control.musicArtist : AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.media.no_app", "Media")
    readonly property string artSource: control ? control.musicArt : ""
    readonly property bool playing: control ? control.musicPlaying : false
    readonly property bool active: control ? control.hasMusic : false

    radius: Theme.radiusLarge
    color: Theme.surface
    border.width: 1
    border.color: active ? Theme.barBorderHover : Theme.border

    Behavior on color { ColorAnimation { duration: Theme.animationStandard } }
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
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        Image {
            anchors.fill: parent
            source: module.artSource
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            cache: false
            asynchronous: true
            visible: module.artSource !== ""
        }

        Text {
            anchors.centerIn: parent
            visible: module.artSource === ""
            text: "󰝚"
            color: Theme.shellIconMain
            font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIconLarge }
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
