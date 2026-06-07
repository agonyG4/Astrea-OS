import QtQuick

QtObject {
    id: root

    property string style: "Notch"
    property bool hasMusic: false
    property bool isExpanded: false
    property bool showCompactMusic: false
    property bool showGamemodeNotify: false
    property bool showEmailCodeNotify: false

    readonly property bool isNotch: style === "Notch"
    readonly property bool isExpandedOrNotify: isExpanded || showGamemodeNotify || showEmailCodeNotify

    readonly property int width: {
        if (showEmailCodeNotify)
            return isNotch ? 310 : 300
        if (showGamemodeNotify)
            return isNotch ? 210 : 100
        if (!hasMusic)
            return isNotch ? 210 : 120
        if (isExpanded)
            return isNotch ? 380 : 360
        if (!showCompactMusic)
            return isNotch ? 210 : 120
        return isNotch ? 210 : 180
    }

    readonly property int height: {
        if (showEmailCodeNotify)
            return 78
        if (showGamemodeNotify)
            return 100
        if (!hasMusic)
            return isNotch ? 32 : 34
        if (isExpanded)
            return 160
        return isNotch ? 32 : 34
    }

    readonly property int radius: {
        if (showEmailCodeNotify)
            return 28
        if (showGamemodeNotify)
            return 32
        if (isExpanded)
            return (isNotch && !hasMusic) ? 17 : 32
        return 17
    }

    readonly property int topMargin: isNotch ? 0 : 8
}
