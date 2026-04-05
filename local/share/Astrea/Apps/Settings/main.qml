import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import "components"

ApplicationWindow {
    id: window
    visible: true
    width: 950
    height: 650
    minimumWidth: 950
    minimumHeight: 650
    maximumWidth: 950
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

    readonly property var pages: [
        "pages/system/system.qml",
        "pages/display/display.qml",
        "pages/apps/apps.qml",
        "pages/system/performance.qml",
        "pages/connectivity/internet.qml",
        "pages/connectivity/bluetooth.qml",
        "pages/personalization/personalization.qml",
        "pages/paper/wallpaper.qml",
        "pages/connectivity/audio.qml",
        "pages/display/island.qml",
        "pages/system/storage.qml"
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
        pageLoader.setSource("pages/personalization/user.qml")
    }

    Component.onCompleted:  pageLoader.setSource(pages[0])

    // ── Nav model ─────────────────────────────────────────────────────────
    ListModel {
        id: navModel
        ListElement { label: "System";          sym: "\uf303"; iconSource: "";                                                                          iconKey: "" }           // nf-linux-archlinux
        ListElement { label: "Display";         sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/display.svg";         iconKey: "display" }
        ListElement { label: "Apps";            sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/apps.svg";            iconKey: "apps" }
        ListElement { label: "Performance";     sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/performance.svg";     iconKey: "performance" }
        ListElement { label: "Internet";        sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/network.svg";         iconKey: "network" }
        ListElement { label: "Bluetooth";       sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/bluetooth.svg";       iconKey: "bluetooth" }
        ListElement { label: "Personalization"; sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/theme.svg";           iconKey: "theme" }
        ListElement { label: "Paper";           sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/wallpaper.svg";       iconKey: "wallpaper" }
        ListElement { label: "Audio";           sym: "";       iconSource: "file:///home/agony/.local/share/Astrea/icons/settings/audio.svg";           iconKey: "audio" }
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
        color: Qt.rgba(0.11, 0.11, 0.12, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        clip: true

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
                Layout.preferredWidth: 200
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
                    pageLoader.setSource("pages/paper/lockscreen.qml")
                else if (page === "screensaver")
                    pageLoader.setSource("pages/paper/screensaver.qml")
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
