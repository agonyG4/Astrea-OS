import QtQuick
import QtQuick.Controls
import ".." as Components

Label {
    property color textColor: Components.Theme.textPrimary

    font.family: Components.Theme.fontFamily
    font.hintingPreference: Font.PreferVerticalHinting
    font.kerning: true
    renderType: Text.NativeRendering
    antialiasing: true
    color: textColor

    Behavior on color {
        ColorAnimation { duration: Components.Theme.animationFast; easing.type: Easing.OutCubic }
    }
}
