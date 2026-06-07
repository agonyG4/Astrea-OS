import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import "AstreaComponents"
import "AstreaI18n" as AstreaI18n

ApplicationWindow {
    id: window
    title: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["settings.title"]) || "Astrea Settings"
    visible: true
    readonly property int defaultWidth: 1050
    readonly property int defaultHeight: 650
    width: defaultWidth
    height: defaultHeight
    minimumWidth: 800
    minimumHeight: 500
    maximumWidth: 1400
    maximumHeight: 650
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeNormal
    font.weight: Theme.fontWeightNormal
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
    property int currentPageIndex: 0

    function resetWindowSize() {
        width = defaultWidth
        height = defaultHeight
    }

    readonly property var pages: [
        "pages/system/System.qml",
        "pages/system/SoftwareUpdate.qml",
        "pages/system/Language.qml",
        "pages/display/Display.qml",
        "pages/apps/Apps.qml",
        "pages/system/Performance.qml",
        "pages/gaming/Gamescope.qml",
        "pages/gaming/Proton.qml",
        "pages/connectivity/Internet.qml",
        "pages/connectivity/Bluetooth.qml",
        "pages/personalization/Personalization.qml",
        "pages/paper/Wallpaper.qml",
        "pages/connectivity/Audio.qml",
        "pages/display/Island.qml",
        "pages/system/Storage.qml",
        "pages/system/Components.qml",
        "pages/system/Services.qml",
        "pages/gaming/Compatibility.qml"
    ]

    readonly property var sectionPages: ({
        "-100": {
            title: "Desempenho",
            groups: [
                {
                    title: "",
                    items: [
                        { label: "SteamOS",     sublabel: "Gamescope session, resolution, scaling and launch flags", pageIndex: 6,  sym: "\uf11b", iconKey: "" },
                        { label: "Proton",      sublabel: "Compatibility flags and astrea-gaming launch command",     pageIndex: 7,  sym: "\uf135", iconKey: "" },
                        { label: "Performance", sublabel: "Power, latency and game performance controls",             pageIndex: 5,  sym: "",       iconKey: "performance" },
                        { label: "Components",  sublabel: "Turn off shell surfaces to reduce memory usage",           pageIndex: 15, sym: "\uf0e8", iconKey: "" }
                    ]
                }
            ]
        },
        "-101": {
            title: "Aparência",
            groups: [
                {
                    title: "",
                    items: [
                        { label: "Display",         sublabel: "Monitor layout, scale and refresh settings", pageIndex: 3,  sym: "",       iconKey: "display" },
                        { label: "Personalization", sublabel: "Theme, accent and interface preferences",     pageIndex: 10, sym: "",       iconKey: "theme" },
                        { label: "Paper",           sublabel: "Wallpaper, lock screen and screen saver",      pageIndex: 11, sym: "",       iconKey: "wallpaper" },
                        { label: "Island",          sublabel: "Dynamic island and desktop overlay behavior",  pageIndex: 13, sym: "\uf0c2", iconKey: "" }
                    ]
                }
            ]
        },
        "-102": {
            title: "Mais Ajustes",
            groups: [
                {
                    title: "",
                    items: [
                        { label: "Language", sublabel: "Language, region and locale preferences", pageIndex: 2,  sym: "\uf1ab", iconKey: "" },
                        { label: "Apps",     sublabel: "Installed applications and defaults",      pageIndex: 4,  sym: "",       iconKey: "apps" },
                        { label: "Compatibilidade", sublabel: "Windows executables, Wine/Proton runner and wrappers", pageIndex: 17, sym: "\uf17a", iconKey: "" },
                        { label: "Storage",    sublabel: "Disk usage and cleanup options",           pageIndex: 14, sym: "\uf1c0", iconKey: "" },
                        { label: "Components", sublabel: "Desktop, topbar and shell component toggles", pageIndex: 15, sym: "\uf0e8", iconKey: "" },
                        { label: "Services",   sublabel: "Astrea background services and startup units", pageIndex: 16, sym: "\uf085", iconKey: "" }
                    ]
                }
            ]
        }
    })

    function loadPage(index, navIndex) {
        if (index < 0 || index >= pages.length)
            return
        selectedIndex = navIndex === undefined ? index : navIndex
        currentPageIndex = index
        pageLoader.setSource(pages[index])
    }

    function loadSection(index) {
        const section = sectionPages[String(index)]
        if (!section)
            return
        selectedIndex = index
        currentPageIndex = -1
        pageLoader.setSource("pages/SectionOverview.qml", {
            sectionTitle: section.title,
            groups: section.groups,
            sidebarIndex: index
        })
    }

    function navigateTo(index) {
        if (index < 0) {
            loadSection(index)
            return
        }

        if (index === currentPageIndex && selectedIndex === index) {
            // Allow returning to the main page of a section if we are on a sub-page (like lockscreen)
            if (pageLoader.source.toString().indexOf(pages[index]) === -1) {
                loadPage(index, index)
            }
            return
        }
        loadPage(index, index)
    }

    function navigateToUserConfig() {
        selectedIndex = -1
        pageLoader.setSource("pages/personalization/User.qml")
    }

    Component.onCompleted: {
        resetWindowSize()
        Qt.callLater(resetWindowSize)
        loadPage(0, 0)
    }

    // ── Nav model ─────────────────────────────────────────────────────────
    ListModel {
        id: navModel
        ListElement { kind: "page";   label: "System";          labelKey: "settings.nav.system";          sym: "\uf303"; iconSource: ""; iconKey: "";                pageIndex: 0;    sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "page";   label: "Software Update"; labelKey: "settings.nav.software_update"; sym: "";       iconSource: ""; iconKey: "software-center"; pageIndex: 1;    sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "page";   label: "Internet";        labelKey: "settings.nav.internet";        sym: "";       iconSource: ""; iconKey: "network";         pageIndex: 8;    sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "page";   label: "Bluetooth";       labelKey: "settings.nav.bluetooth";       sym: "";       iconSource: ""; iconKey: "bluetooth";       pageIndex: 9;    sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "page";   label: "Audio";           labelKey: "settings.nav.audio";           sym: "";       iconSource: ""; iconKey: "audio";           pageIndex: 12;   sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "page";   label: "Components";      labelKey: "";                            sym: "\uf0e8"; iconSource: ""; iconKey: "";                pageIndex: 15;   sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "page";   label: "Services";        labelKey: "";                            sym: "\uf085"; iconSource: ""; iconKey: "";                pageIndex: 16;   sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "spacer"; label: "";                labelKey: "";                            sym: "";       iconSource: ""; iconKey: "";                pageIndex: -999; sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "group";  label: "Desempenho";      labelKey: "";                            sym: "";       iconSource: ""; iconKey: "performance";     pageIndex: -100; sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "group";  label: "Aparência";       labelKey: "";                            sym: "";       iconSource: ""; iconKey: "theme";           pageIndex: -101; sectionKey: ""; parentSection: ""; expanded: false }
        ListElement { kind: "group";  label: "Mais Ajustes";    labelKey: "";                            sym: "\uf013"; iconSource: ""; iconKey: "";                pageIndex: -102; sectionKey: ""; parentSection: ""; expanded: false }
    }

    // ── Drop shadow ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 0
        color: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled:        true
            shadowColor:          Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.24) : Qt.rgba(0, 0, 0, 0.6)
            shadowBlur:           1.0
            shadowVerticalOffset: 8
        }
    }

    // ── Main container ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.windowBackground
        border.width: 1
        border.color: Theme.windowBorder
        clip: false

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
            border.color: Theme.themeMode === 1
                ? Qt.rgba(1, 1, 1, Theme.shellStyle === 0 ? 0.22 : Theme.shellStyle === 2 ? 0.30 : 0.14)
                : Qt.rgba(1, 1, 1, Theme.shellStyle === 0 ? 0.04 : 0.02)
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
                translationMessages: AstreaI18n.I18n.messages || ({})
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
            function onNavigateToPage(pageIndex, sidebarIndex) {
                window.loadPage(pageIndex, sidebarIndex)
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
