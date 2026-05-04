import QtQuick 2.15
import QtQuick.Controls 2.15
import "../.."

Label {
    property color textColor: Theme.textPrimary

    font.family: "Inter Display"
    font.hintingPreference: Font.PreferVerticalHinting
    font.kerning: true
    renderType: Text.NativeRendering
    antialiasing: true
    color: textColor
}
