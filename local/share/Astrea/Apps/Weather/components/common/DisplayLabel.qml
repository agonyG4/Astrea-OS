import QtQuick 2.15
import QtQuick.Controls 2.15

Label {
    property color textColor: "#1C1C1E"

    font.family: "Inter Display"
    antialiasing: true
    color: textColor

    Behavior on color {
        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
}
