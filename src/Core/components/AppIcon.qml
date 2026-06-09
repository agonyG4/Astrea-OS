import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    property var appData: null
    property var entry: appData
    property string iconName: resolveIconName(entry)
    property string fallbackIconName: ""
    readonly property string resolvedIconName: iconName.length > 0 ? iconName : fallbackIconName
    property string fallbackText: initials(displayName(entry))
    property int iconSize: 52
    property int iconRadius: 14
    property int fallbackRadius: iconRadius
    property int fallbackFontSize: Math.max(11, Math.round(Math.min(width, height) * 0.36))
    property int iconPadding: Math.max(2, Math.round(iconSize * 0.06))
    property bool showFallbackText: true
    property int sourcePixelSize: Math.max(64, Math.round(iconSize * 2))
    property color fallbackColor: Qt.rgba(1, 1, 1, 0.08)
    property color fallbackBorderColor: Qt.rgba(1, 1, 1, 0.14)
    property color fallbackTextColor: "#f5f5f7"
    property string fallbackFontFamily: "Inter"
    property int retryCount: 0
    readonly property bool hasIcon: iconImage.status === Image.Ready

    width: iconSize
    height: iconSize
    radius: fallbackRadius
    color: hasIcon ? "transparent" : fallbackColor
    border.width: hasIcon ? 0 : 1
    border.color: fallbackBorderColor
    clip: true
    antialiasing: true

    function displayName(value) {
        if (!value)
            return "App"
        return value.name || value.title || value.className || value.class || value.initialClass || "App"
    }

    function initials(name) {
        const parts = String(name || "App").replace(/[-_.]+/g, " ").split(/\s+/).filter(part => part.length > 0)
        if (parts.length === 0)
            return "A"
        if (parts.length === 1)
            return parts[0].slice(0, 1).toUpperCase()
        return (parts[0].slice(0, 1) + parts[1].slice(0, 1)).toUpperCase()
    }

    function resolveIconName(value) {
        if (!value)
            return ""
        if (value.iconSource)
            return value.iconSource
        if (value.astreaIcon)
            return value.astreaIcon
        if (value.astreaIconName)
            return value.astreaIconName

        const cls = String(value.className || value.class || value.initialClass || "").toLowerCase()
        const text = String((value.title || value.name || "") + " " + cls).toLowerCase()

        if (cls.indexOf("zen") >= 0 || text.indexOf("zen") >= 0)
            return "zen-browser"
        if (cls.indexOf("spotify") >= 0 || text.indexOf("spotify") >= 0)
            return "spotify"

        if (value.icon_path)
            return value.icon_path
        if (value.iconPath)
            return value.iconPath
        if (value.icon) {
            const explicitIcon = String(value.icon).toLowerCase()
            if (cls === "steam_app_default" && explicitIcon === "steam")
                return ""
            return value.icon
        }

        if (cls === "org.vinegarhq.sober")
            return "org.vinegarhq.Sober"
        if (cls.indexOf("kitty") >= 0)
            return "kitty"
        if (cls.indexOf("code") >= 0 || cls.indexOf("cursor") >= 0)
            return "visual-studio-code"
        if (cls.indexOf("discord") >= 0)
            return "discord"
        const steamGame = cls.match(/^steam_app_(\d+)$/)
        if (steamGame)
            return "steam_icon_" + steamGame[1]
        if (cls === "steam_app_default")
            return ""
        if (cls.indexOf("steam") >= 0)
            return "steam"
        if (cls === "obsidian" || text.indexOf("obsidian") >= 0)
            return "obsidian"
        if (cls === "obs" || cls.indexOf("obsproject") >= 0 || cls.indexOf("obs-studio") >= 0)
            return "com.obsproject.Studio"
        if (text.indexOf("finder") >= 0)
            return "folder"
        if (cls.indexOf("org.quickshell") >= 0)
            return "application-x-executable"
        return cls.indexOf(".") >= 0 ? "" : cls
    }

    function iconSource(name) {
        const text = String(name || "")
        if (text.length === 0)
            return ""
        if (text.indexOf("://") >= 0)
            return text
        if (text.indexOf("/") >= 0)
            return "file://" + text
        return "image://icon/" + text
    }

    function reloadIcon() {
        const nextSource = root.iconSource(root.resolvedIconName)
        if (nextSource.length === 0)
            return

        iconImage.source = ""
        Qt.callLater(() => {
            if (root.iconSource(root.resolvedIconName) === nextSource)
                iconImage.source = nextSource
        })
    }

    onResolvedIconNameChanged: {
        retryCount = 0
        reloadIcon()
    }

    Item {
        id: iconFrame

        anchors.fill: parent
        anchors.margins: root.iconPadding
    }

    Image {
        id: iconImage

        anchors.fill: iconFrame
        source: root.iconSource(root.resolvedIconName)
        sourceSize: Qt.size(root.sourcePixelSize, root.sourcePixelSize)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
        cache: true
        visible: status === Image.Ready && root.iconRadius <= 0

        onStatusChanged: {
            if (status === Image.Error && root.resolvedIconName.length > 0 && root.retryCount < 2) {
                root.retryCount += 1
                iconRetryTimer.restart()
            }
        }
    }

    Rectangle {
        id: iconMask

        anchors.fill: iconFrame
        radius: Math.max(0, root.iconRadius - root.iconPadding)
        antialiasing: true
        visible: false
    }

    OpacityMask {
        anchors.fill: iconFrame
        source: iconImage
        maskSource: iconMask
        antialiasing: true
        visible: iconImage.status === Image.Ready && root.iconRadius > 0
    }

    Timer {
        id: iconRetryTimer
        interval: 180
        repeat: false
        onTriggered: root.reloadIcon()
    }

    Text {
        anchors.centerIn: parent
        text: root.fallbackText
        color: root.fallbackTextColor
        font.family: root.fallbackFontFamily
        font.pixelSize: root.fallbackFontSize
        font.weight: Font.DemiBold
        visible: !root.hasIcon && root.showFallbackText
    }
}
