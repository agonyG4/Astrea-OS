import QtQuick
import ".." as Components

Rectangle {
    id: root

    property string leftLabel: ""
    property string rightLabel: ""
    property string leftText: leftLabel
    property string rightText: rightLabel
    property string leftIconSource: ""
    property string rightIconSource: ""
    property string leftIconText: ""
    property string rightIconText: ""
    property string iconFontFamily: Components.Theme.fontFamily
    property bool leftEnabled: true
    property bool rightEnabled: true
    property int selectedIndex: -1
    property int fontPixelSize: Components.Theme.fontSizeNormal
    property int iconSize: Math.round(fontPixelSize + 4)
    property int controlWidth: 0
    property int controlHeight: 34
    property int segmentWidth: 96
    property int cornerRadius: Math.round(controlHeight / 2)
    property int contentSpacing: Components.Theme.spacingSmall
    property color accentColor: Components.Theme.accent
    property bool separatorVisible: false
    property int separatorInset: 8
    property color separatorColor: Components.Theme.cardBorder
    property bool leftIconOutline: false
    property bool rightIconOutline: false
    property int iconOutlineSize: Math.round(Math.min(controlHeight - 8, iconSize + 8))
    property int iconOutlineRadius: 9
    property int iconOutlineBorderWidth: 1
    property color iconOutlineFillColor: "transparent"
    property color iconOutlineBorderColor: Qt.rgba(1, 1, 1, 0.20)
    property color iconOutlinePressedBorderColor: Qt.rgba(1, 1, 1, 0.30)
    property color iconOutlinePressedFillColor: Qt.rgba(1, 1, 1, 0.07)

    readonly property bool leftHovered: leftHover.hovered
    readonly property bool rightHovered: rightHover.hovered
    readonly property bool leftPressed: leftArea.pressed
    readonly property bool rightPressed: rightArea.pressed
    property color leftFillColor: {
        if (!root.leftEnabled)
            return "transparent"
        if (root.selectedIndex === 0)
            return root.accentColor
        if (root.leftIconOutline)
            return "transparent"
        if (leftArea.pressed)
            return Qt.rgba(1, 1, 1, 0.12)
        return leftHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    }
    property color rightFillColor: {
        if (!root.rightEnabled)
            return "transparent"
        if (root.selectedIndex === 1)
            return root.accentColor
        if (root.rightIconOutline)
            return "transparent"
        if (rightArea.pressed)
            return Qt.rgba(1, 1, 1, 0.12)
        return rightHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    }

    signal leftClicked()
    signal rightClicked()
    signal clicked(int index)

    implicitWidth: controlWidth > 0 ? controlWidth : segmentWidth * 2
    implicitHeight: controlHeight
    radius: Math.min(cornerRadius, height / 2)
    color: Components.Theme.cardBg
    border.width: 1
    border.color: Components.Theme.cardBorder
    clip: true

    Behavior on color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
    Behavior on leftFillColor { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
    Behavior on rightFillColor { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }

    onLeftFillColorChanged: segmentFill.requestPaint()
    onRightFillColorChanged: segmentFill.requestPaint()
    onRadiusChanged: segmentFill.requestPaint()
    onWidthChanged: segmentFill.requestPaint()
    onHeightChanged: segmentFill.requestPaint()

    Canvas {
        id: segmentFill
        anchors.fill: parent

        function drawLeftSegment(ctx, x, y, w, h, r) {
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w, y)
            ctx.lineTo(x + w, y + h)
            ctx.lineTo(x + r, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - r)
            ctx.lineTo(x, y + r)
            ctx.quadraticCurveTo(x, y, x + r, y)
            ctx.closePath()
        }

        function drawRightSegment(ctx, x, y, w, h, r) {
            ctx.beginPath()
            ctx.moveTo(x, y)
            ctx.lineTo(x + w - r, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + r)
            ctx.lineTo(x + w, y + h - r)
            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
            ctx.lineTo(x, y + h)
            ctx.closePath()
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var inset = root.border.width
            var h = Math.max(0, height - inset * 2)
            var half = width / 2
            var r = Math.max(0, Math.min(root.radius - inset, h / 2))

            ctx.fillStyle = root.leftFillColor
            drawLeftSegment(ctx, inset, inset, half - inset, h, r)
            ctx.fill()

            ctx.fillStyle = root.rightFillColor
            drawRightSegment(ctx, half, inset, half - inset, h, r)
            ctx.fill()
        }
    }

    Rectangle {
        visible: root.separatorVisible
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: root.separatorInset
        anchors.bottomMargin: root.separatorInset
        width: 1
        radius: 0.5
        color: root.separatorColor
    }

    Rectangle {
        id: leftSegment
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width / 2
        color: "transparent"

        HoverHandler { id: leftHover; enabled: root.leftEnabled }

        Rectangle {
            anchors.centerIn: parent
            width: root.iconOutlineSize
            height: root.iconOutlineSize
            radius: Math.min(root.iconOutlineRadius, height / 2)
            visible: root.leftIconOutline
                && root.leftEnabled
                && (root.leftHovered || root.leftPressed)
            color: root.leftPressed ? root.iconOutlinePressedFillColor : root.iconOutlineFillColor
            border.width: root.iconOutlineBorderWidth
            border.color: root.leftPressed
                ? root.iconOutlinePressedBorderColor
                : root.iconOutlineBorderColor

            Behavior on color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.centerIn: parent
            spacing: (root.leftText !== "" && (root.leftIconText !== "" || root.leftIconSource !== "")) ? root.contentSpacing : 0

            Image {
                visible: root.leftIconSource !== ""
                source: root.leftIconSource
                width: root.iconSize
                height: root.iconSize
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                opacity: root.leftEnabled ? 1 : Components.Theme.opacityMuted
            }

            Text {
                visible: root.leftIconText !== "" && root.leftIconSource === ""
                text: root.leftIconText
                color: root.leftEnabled
                    ? (root.selectedIndex === 0 ? Components.Theme.accentForeground : Components.Theme.textSecondary)
                    : Components.Theme.textTertiary
                font.family: root.iconFontFamily
                font.pixelSize: root.iconSize
                font.weight: Components.Theme.fontWeightMedium
            }

            Text {
                visible: root.leftText !== ""
                text: root.leftText
                color: root.leftEnabled
                    ? (root.selectedIndex === 0 ? Components.Theme.accentForeground : Components.Theme.textPrimary)
                    : Components.Theme.textTertiary
                font.family: Components.Theme.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: Components.Theme.fontWeightMedium
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: leftArea
            anchors.fill: parent
            cursorShape: root.leftEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (!root.leftEnabled)
                    return
                root.leftClicked()
                root.clicked(0)
            }
        }
    }

    Rectangle {
        id: rightSegment
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width / 2
        color: "transparent"

        HoverHandler { id: rightHover; enabled: root.rightEnabled }

        Rectangle {
            anchors.centerIn: parent
            width: root.iconOutlineSize
            height: root.iconOutlineSize
            radius: Math.min(root.iconOutlineRadius, height / 2)
            visible: root.rightIconOutline
                && root.rightEnabled
                && (root.rightHovered || root.rightPressed)
            color: root.rightPressed ? root.iconOutlinePressedFillColor : root.iconOutlineFillColor
            border.width: root.iconOutlineBorderWidth
            border.color: root.rightPressed
                ? root.iconOutlinePressedBorderColor
                : root.iconOutlineBorderColor

            Behavior on color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.centerIn: parent
            spacing: (root.rightText !== "" && (root.rightIconText !== "" || root.rightIconSource !== "")) ? root.contentSpacing : 0

            Image {
                visible: root.rightIconSource !== ""
                source: root.rightIconSource
                width: root.iconSize
                height: root.iconSize
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                opacity: root.rightEnabled ? 1 : Components.Theme.opacityMuted
            }

            Text {
                visible: root.rightIconText !== "" && root.rightIconSource === ""
                text: root.rightIconText
                color: root.rightEnabled
                    ? (root.selectedIndex === 1 ? Components.Theme.accentForeground : Components.Theme.textSecondary)
                    : Components.Theme.textTertiary
                font.family: root.iconFontFamily
                font.pixelSize: root.iconSize
                font.weight: Components.Theme.fontWeightMedium
            }

            Text {
                visible: root.rightText !== ""
                text: root.rightText
                color: root.rightEnabled
                    ? (root.selectedIndex === 1 ? Components.Theme.accentForeground : Components.Theme.textPrimary)
                    : Components.Theme.textTertiary
                font.family: Components.Theme.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: Components.Theme.fontWeightMedium
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rightArea
            anchors.fill: parent
            cursorShape: root.rightEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (!root.rightEnabled)
                    return
                root.rightClicked()
                root.clicked(1)
            }
        }
    }

}
