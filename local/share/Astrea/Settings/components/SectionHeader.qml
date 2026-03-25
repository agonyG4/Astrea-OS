import QtQuick

Text {
    id: labelRoot
    // No shadowing property 'text'! Simply use Text's own property.
    property color textSecondary: "#98989f"

    font.pixelSize: 10
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
    color: textSecondary
}
