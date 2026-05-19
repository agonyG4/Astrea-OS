import QtQuick

TextEdit {
    id: root

    visible: false

    function copyText(value) {
        text = value || ""
        forceActiveFocus()
        select(0, text.length)
        copy()
        text = ""
    }
}
