import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import "components"

ApplicationWindow {
    id: window
    title: "Astrea Settings"
    visible: true
    readonly property int defaultWidth: 1050
    readonly property int defaultHeight: 650
    width: defaultWidth
    height: defaultHeight
    minimumWidth: 800
    minimumHeight: 500
    maximumWidth: 1400
    maximumHeight: 650
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    onClosing: Qt.quit()
    background: Rectangle { color: "transparent" }

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color accent: Theme.accent
    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary

    // ── Navigation state ──────────────────────────────────────────────────
    property int selectedIndex: 0

    function resetWindowSize() {
        width = defaultWidth
        height = defaultHeight
    }

    readonly property var pages: [
        "pages/system/System.qml",
        "pages/system/SoftwareUpdate.qml",
        "pages/display/Display.qml",
        "pages/apps/Apps.qml",
        "pages/system/Performance.qml",
        "pages/connectivity/Internet.qml",
        "pages/connectivity/Bluetooth.qml",
        "pages/personalization/Personalization.qml",
        "pages/paper/Wallpaper.qml",
        "pages/connectivity/Audio.qml",
        "pages/display/Island.qml",
        "pages/system/Storage.qml"
    ]

    function navigateTo(index) {
        if (index === selectedIndex) {
            // Allow returning to the main page of a section if we are on a sub-page (like lockscreen)
            if (pageLoader.source.toString().indexOf(pages[index]) === -1) {
                pageLoader.setSource(pages[index])
            }
            return
        }
        selectedIndex = index
        if (index >= 0 && index < pages.length) {
            pageLoader.setSource(pages[index])
        }
    }

    function navigateToUserConfig() {
        selectedIndex = -1
        pageLoader.setSource("pages/personalization/User.qml")
    }

    Component.onCompleted: {
        resetWindowSize()
        Qt.callLater(resetWindowSize)
        pageLoader.setSource(pages[0])
    }

    // ── Nav model ─────────────────────────────────────────────────────────
    ListModel {
        id: navModel
        ListElement { label: "System";          sym: "\uf303"; iconSource: "";                                                                          iconKey: "" }           // nf-linux-archlinux
        ListElement { label: "Software Update"; sym: "";       iconSource: ""; iconKey: "software-center" }
        ListElement { label: "Display";         sym: "";       iconSource: ""; iconKey: "display" }
        ListElement { label: "Apps";            sym: "";       iconSource: ""; iconKey: "apps" }
        ListElement { label: "Performance";     sym: "";       iconSource: ""; iconKey: "performance" }
        ListElement { label: "Internet";        sym: "";       iconSource: ""; iconKey: "network" }
        ListElement { label: "Bluetooth";       sym: "";       iconSource: ""; iconKey: "bluetooth" }
        ListElement { label: "Personalization"; sym: "";       iconSource: ""; iconKey: "theme" }
        ListElement { label: "Paper";           sym: "";       iconSource: ""; iconKey: "wallpaper" }
        ListElement { label: "Audio";           sym: "";       iconSource: ""; iconKey: "audio" }
        ListElement { label: "Island";          sym: "\uf0c2"; iconSource: "";                                                                          iconKey: "" }           // nf-fa-cloud
        ListElement { label: "Storage";         sym: "\uf1c0"; iconSource: "";                                                                          iconKey: "" }           // nf-fa-database
    }

    // ── Drop shadow ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 15
        color: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled:        true
            shadowColor:          Qt.rgba(0, 0, 0, 0.6)
            shadowBlur:           1.0
            shadowVerticalOffset: 8
        }
    }

    // ── Main container ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.windowBackground
        border.width: 1
        border.color: Theme.windowBorder
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.windowWash
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, Theme.shellStyle === 0 ? 0.04 : 0.02)
        }

        // ── Drag handle (barra fina no topo, não bloqueia conteúdo) ───────
        MouseArea {
            id: dragArea
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 14
            cursorShape: Qt.SizeAllCursor
            property point pressOffset
            onPressed:         (mouse) => { pressOffset = Qt.point(mouse.globalX - window.x, mouse.globalY - window.y) }
            onPositionChanged: (mouse) => { if (pressed) { window.x = mouse.globalX - pressOffset.x; window.y = mouse.globalY - pressOffset.y } }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Sidebar {
                id: sidebar
                Layout.preferredWidth: 256
                Layout.fillHeight: true
                model:         navModel
                selectedIndex: window.selectedIndex
                onSelectIndex: (i) => window.navigateTo(i)
                onOpenUserProfile: window.navigateToUserConfig()
            }
// ── Content area ──────────────────────────────────────────────
Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Loader {
        id: pageLoader
        anchors.fill: parent
        onStatusChanged: if (status === Loader.Ready) fadeIn.start()
        
        Connections {
            target: pageLoader.item
            ignoreUnknownSignals: true
            function onNavigateTo(page) {
                if (page === "lockscreen")
                    pageLoader.setSource("pages/paper/Lockscreen.qml")
                else if (page === "screensaver")
                    pageLoader.setSource("pages/paper/Screensaver.qml")
            }
            function onProfileImageChanged() {
                sidebar.avatarVersion += 1
            }
        }

        NumberAnimation {
            id: fadeIn
            target:      pageLoader
            property:    "opacity"
            from:        0
            to:          1
            duration:    180
            easing.type: Easing.OutCubic
        }
    }
}
            
        }
    }
}
