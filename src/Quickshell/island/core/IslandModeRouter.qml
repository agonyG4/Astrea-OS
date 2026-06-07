import QtQuick

Item {
    id: root

    property bool musicEnabled: true
    property string musicTitle: ""
    property bool shouldDisplayMusic: false
    property bool notifyVisible: false
    property bool emailCodeVisible: false

    readonly property bool hasMusic: musicEnabled && musicTitle !== ""
    readonly property bool showCompactMusic: hasMusic && shouldDisplayMusic
    readonly property string activeMode: emailCodeVisible ? "emailCode" : notifyVisible ? "gamemodeNotify" : hasMusic ? "music" : "idle"
}
