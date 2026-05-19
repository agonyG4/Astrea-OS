import QtQuick

Item {
    id: root

    property var entry: null
    property string iconName: resolveIconName(entry)
    property string fallbackText: initials(displayName(entry))
    property color fallbackColor: "#22FFFFFF"
    property color fallbackTextColor: "#E8FFFFFF"
    property int fallbackRadius: 6
    property int fallbackFontSize: Math.max(11, Math.round(Math.min(width, height) * 0.36))

    implicitWidth: 30
    implicitHeight: 30

    function displayName(value) {
        if (!value) return "App"
        return value.name || value.title || value.className || value.class || value.initialClass || "App"
    }

    function initials(name) {
        const parts = String(name || "App").replace(/[-_.]+/g, " ").split(/\s+/).filter(part => part.length > 0)
        if (parts.length === 0) return "A"
        if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase()
        return (parts[0].slice(0, 1) + parts[1].slice(0, 1)).toUpperCase()
    }

    function resolveIconName(value) {
        if (!value) return ""
        if (value.icon) return value.icon
        if (value.iconPath) return value.iconPath
        if (value.icon_path) return value.icon_path

        const cls = String(value.className || value.class || value.initialClass || "").toLowerCase()
        const text = String((value.title || value.name || "") + " " + cls).toLowerCase()

        if (cls.indexOf("zen") >= 0) return "zen-browser"
        if (cls.indexOf("kitty") >= 0) return "kitty"
        if (cls.indexOf("code") >= 0 || cls.indexOf("cursor") >= 0) return "visual-studio-code"
        if (cls.indexOf("spotify") >= 0) return "spotify"
        if (cls.indexOf("discord") >= 0) return "discord"
        if (cls.indexOf("steam") >= 0) return "steam"
        if (cls === "obsidian" || text.indexOf("obsidian") >= 0) return "obsidian"
        if (cls === "obs" || cls.indexOf("obsproject") >= 0 || cls.indexOf("obs-studio") >= 0) return "com.obsproject.Studio"
        if (text.indexOf("finder") >= 0) return "folder"
        if (cls.indexOf("org.quickshell") >= 0) return "application-x-executable"
        return cls
    }

    function iconSource(name) {
        const text = String(name || "")
        if (text.length === 0) return ""
        if (text.indexOf("://") >= 0) return text
        if (text.indexOf("/") >= 0) return "file://" + text
        return "image://icon/" + text
    }

    Image {
        id: image
        anchors.fill: parent
        sourceSize: Qt.size(root.width, root.height)
        source: root.iconSource(root.iconName)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        radius: root.fallbackRadius
        color: root.fallbackColor
        visible: image.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: root.fallbackText
            color: root.fallbackTextColor
            font.pixelSize: root.fallbackFontSize
            font.weight: Font.Medium
        }
    }
}
