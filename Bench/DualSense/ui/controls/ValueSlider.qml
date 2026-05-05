import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea

RowLayout {
    id: row
    property string label: ""
    property int from: 0
    property int to: 255
    property int value: 0
    signal edited(int value)

    spacing: 8

    Text {
        Layout.preferredWidth: 78
        text: row.label
        color: Astrea.Theme.textSecondary
        font.family: Astrea.Theme.fontFamily
        font.pixelSize: Astrea.Theme.fontSizeSmall
    }

    Slider {
        Layout.fillWidth: true
        from: row.from
        to: row.to
        stepSize: 1
        value: row.value
        onMoved: row.edited(Math.max(row.from, Math.min(row.to, Math.round(value))))
    }

    Text {
        Layout.preferredWidth: 32
        horizontalAlignment: Text.AlignRight
        text: String(row.value)
        color: Astrea.Theme.textPrimary
        font.family: Astrea.Theme.monoFontFamily
        font.pixelSize: Astrea.Theme.fontSizeSmall
    }
}
