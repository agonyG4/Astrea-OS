import QtQuick
import QtQuick.Layouts
import ".." as Components
import "../AstreaI18n" as AstreaI18n

Rectangle {
    id: root

    property string label: ""
    property string speed: "0 B/s"
    property var history: []
    property color accentColor: Components.Theme.accent
    property string icon: ""

    Layout.fillWidth: true
    Layout.preferredHeight: 100
    radius: 12
    color: Components.Theme.cardBg
    border.width: 1
    border.color: Components.Theme.cardBorder
    clip: true

    Canvas {
        id: sparkline
        anchors.fill: parent
        anchors.margins: 1
        opacity: 0.22
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const values = Array.isArray(root.history) ? root.history : []
            if (values.length < 2)
                return

            let maxVal = 1
            for (let i = 0; i < values.length; ++i)
                maxVal = Math.max(maxVal, values[i])

            const w = width
            const h = height
            const step = values.length > 1 ? w / (values.length - 1) : w

            ctx.beginPath()
            for (let i = 0; i < values.length; ++i) {
                const x = i * step
                const y = h - ((values[i] / maxVal) * (h - 18)) - 9
                if (i === 0)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }

            ctx.lineWidth = 2
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.strokeStyle = root.accentColor
            ctx.stroke()

            ctx.lineTo(w, h)
            ctx.lineTo(0, h)
            ctx.closePath()
            const gradient = ctx.createLinearGradient(0, 0, 0, h)
            gradient.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24))
            gradient.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.01))
            ctx.fillStyle = gradient
            ctx.fill()
        }

        Connections {
            target: root
            function onHistoryChanged() { sparkline.requestPaint() }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 4

        Rectangle {
            width: 24
            height: 24
            radius: 8
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.30)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.accentColor
                font.family: Components.Theme.fontFamily
                font.pixelSize: 14
                font.weight: Components.Theme.fontWeightBold
            }
        }

        Text {
            text: root.label
            color: Components.Theme.textSecondary
            font.family: Components.Theme.fontFamily
            font.pixelSize: Components.Theme.fontSizeSmall
            font.weight: Components.Theme.fontWeightMedium
        }

        Text {
            text: root.speed
            color: "#ffffff"
            font.family: Components.Theme.fontFamily
            font.pixelSize: 20
            font.weight: Components.Theme.fontWeightBold
        }

        Text {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["core.components.feedback.speed_card.text.per_second"]) || "per second")
            color: Components.Theme.textSecondary
            opacity: 0.5
            font.family: Components.Theme.fontFamily
            font.pixelSize: 11
            font.weight: Components.Theme.fontWeightLight
        }

        Item { Layout.fillHeight: true }
    }
}
