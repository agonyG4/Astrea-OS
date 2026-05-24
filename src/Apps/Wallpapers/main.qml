import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "AstreaComponents" as Astrea

ApplicationWindow {
    id: window

    visible: true
    readonly property int defaultWidth: 1400
    readonly property int defaultHeight: 800
    width: defaultWidth
    height: defaultHeight
    minimumWidth: 960
    minimumHeight: 560
    maximumWidth: 1400
    maximumHeight: 800
    title: "Wallpapers"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    font.family: Astrea.Theme.fontFamily
    font.pixelSize: Astrea.Theme.fontSizeNormal
    font.weight: Astrea.Theme.fontWeightNormal
    background: Rectangle { color: "transparent" }

    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")
    readonly property string wallpaperManager: astreaRoot + "/Core/bridge/wallpaper/wallpaper_manager.py"
    readonly property int pagePad: Astrea.Theme.pageMargin
    readonly property int sidebarWidth: sidebarCollapsed ? 58 : 206

    property string statusText: ""
    property string errorText: ""
    property string pendingSlug: ""
    property string pendingName: ""
    property bool sidebarCollapsed: false
    property int selectedIndex: -1
    property var selectedItem: selectedIndex >= 0 && selectedIndex < wallpaperModel.count ? wallpaperModel.get(selectedIndex) : null

    function fileUrl(path, version) {
        if (!path)
            return ""
        return encodeURI("file://" + path) + "?t=" + (version || 0)
    }

    function runProcess(proc) {
        proc.running = false
        Qt.callLater(() => proc.running = true)
    }

    function parseJson(raw, label) {
        try {
            return JSON.parse(raw || "{}")
        } catch (err) {
            errorText = label + " parse failed"
            console.log("Wallpapers", label, err, raw)
            return null
        }
    }

    function loadWallpapers() {
        errorText = ""
        statusText = "Loading..."
        runProcess(listProc)
    }

    function setSelectedBySlug(slug) {
        if (!slug)
            return
        for (let i = 0; i < wallpaperModel.count; i++) {
            if (wallpaperModel.get(i).slug === slug) {
                grid.currentIndex = i
                return
            }
        }
    }

    function applyTo(scope) {
        if (!selectedItem)
            return
        errorText = ""
        applyProc.scope = scope
        applyProc.sourcePath = selectedItem.wallpaperPath
        applyProc.wallpaperName = selectedItem.name
        statusText = scope === "lockscreen" ? "Applying to lockscreen..." : "Applying wallpaper..."
        runProcess(applyProc)
    }

    function renameSelected() {
        if (!selectedItem)
            return
        const nextName = nameInput.text.trim()
        if (!nextName || nextName === selectedItem.name)
            return
        errorText = ""
        pendingSlug = selectedItem.slug
        renameProc.slug = selectedItem.slug
        renameProc.wallpaperName = nextName
        statusText = "Renaming..."
        runProcess(renameProc)
    }

    function requestDeleteSelected() {
        if (!selectedItem)
            return
        errorText = ""
        pendingSlug = selectedItem.slug
        pendingName = selectedItem.name
        confirmDelete.open()
    }

    function deletePending() {
        if (!pendingSlug)
            return
        deleteProc.slug = pendingSlug
        statusText = "Removing..."
        runProcess(deleteProc)
    }

    onClosing: Qt.quit()

    ListModel {
        id: wallpaperModel
    }

    Process {
        id: listProc
        running: false
        property string output: ""
        command: ["python3", window.wallpaperManager, "list-user"]
        stdout: SplitParser { onRead: data => listProc.output += data }
        stderr: SplitParser { onRead: data => window.errorText = data.trim() }
        onExited: code => {
            if (code !== 0) {
                statusText = ""
                listProc.output = ""
                return
            }
            const payload = window.parseJson(listProc.output, "list")
            wallpaperModel.clear()
            if (payload && payload.user) {
                for (const item of payload.user) {
                    wallpaperModel.append({
                        slug: item.slug || "",
                        name: item.name || item.slug || "Wallpaper",
                        wallpaperPath: item.wallpaperPath || "",
                        thumbPath: item.thumbPath || item.wallpaperPath || "",
                        thumbMtime: item.thumbMtime || 0,
                        blurredPath: item.blurredPath || "",
                        baseDir: item.baseDir || ""
                    })
                }
            }
            if (wallpaperModel.count > 0 && grid.currentIndex < 0)
                grid.currentIndex = 0
            statusText = wallpaperModel.count + " wallpapers"
            listProc.output = ""
        }
    }

    Process {
        id: applyProc
        running: false
        property string scope: "wallpaper"
        property string sourcePath: ""
        property string wallpaperName: ""
        command: [
            "python3", window.wallpaperManager, "apply",
            "--scope", scope,
            "--src", sourcePath,
            "--name", wallpaperName
        ]
        stdout: SplitParser { onRead: data => statusText = data.trim() ? "Applied" : statusText }
        stderr: SplitParser { onRead: data => window.errorText = data.trim() }
        onExited: code => statusText = code === 0 ? "Applied" : ""
    }

    Process {
        id: renameProc
        running: false
        property string slug: ""
        property string wallpaperName: ""
        command: [
            "python3", window.wallpaperManager, "rename-user",
            "--slug", slug,
            "--name", wallpaperName
        ]
        stderr: SplitParser { onRead: data => window.errorText = data.trim() }
        onExited: code => {
            const oldSlug = pendingSlug
            statusText = code === 0 ? "Renamed" : ""
            loadWallpapers()
            Qt.callLater(() => setSelectedBySlug(oldSlug))
        }
    }

    Process {
        id: deleteProc
        running: false
        property string slug: ""
        command: ["python3", window.wallpaperManager, "delete-user", "--slug", slug]
        stderr: SplitParser { onRead: data => window.errorText = data.trim() }
        onExited: code => {
            statusText = code === 0 ? "Removed" : ""
            if (code === 0)
                pendingSlug = ""
            deleteProc.output = ""
            loadWallpapers()
        }
    }

    Component.onCompleted: loadWallpapers()

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        color: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.24) : Qt.rgba(0, 0, 0, 0.6)
            shadowBlur: 1.0
            shadowVerticalOffset: 8
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Astrea.Theme.windowBackground
        border.width: 1
        border.color: Astrea.Theme.windowBorder

        Rectangle {
            anchors.fill: parent
            color: Astrea.Theme.windowWash
        }

        MouseArea {
            property point pressPos
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 54
            onPressed: mouse => pressPos = Qt.point(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (pressed) {
                    window.setX(window.x + mouse.x - pressPos.x)
                    window.setY(window.y + mouse.y - pressPos.y)
                }
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: window.pagePad
            }
            spacing: Astrea.Theme.spacingLarge

            Astrea.SidebarFrame {
                Layout.preferredWidth: window.sidebarWidth
                Layout.fillHeight: true
                topMargin: 0
                bottomMargin: 0
                leftMargin: 0
                rightMargin: 0
                cornerRadius: 18
                contentTopPadding: Astrea.Theme.spacingMedium
                contentBottomPadding: Astrea.Theme.spacingLarge
                contentSpacing: Astrea.Theme.spacing

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: Astrea.Theme.animationNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    Astrea.SidebarCollapseButton {
                        anchors {
                            right: parent.right
                            rightMargin: window.sidebarCollapsed ? 13 : 14
                            verticalCenter: parent.verticalCenter
                        }
                        collapsed: window.sidebarCollapsed
                        controlSize: 30
                        onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                    }
                }

                Column {
                    width: parent.width - 28
                    x: 14
                    spacing: 2
                    visible: !window.sidebarCollapsed
                    opacity: window.sidebarCollapsed ? 0 : 1

                    Behavior on opacity { NumberAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }

                    Text {
                        width: parent.width
                        text: "Wallpapers"
                        color: Astrea.Theme.textPrimary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeLarge
                        font.weight: Astrea.Theme.fontWeightDemiBold
                        font.letterSpacing: 0
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: window.statusText || "Managed library"
                        color: Astrea.Theme.textSecondary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    width: parent.width - 28
                    x: 14
                    height: 1
                    color: Astrea.Theme.cardBorder
                    visible: !window.sidebarCollapsed
                }

                Item { width: 1; height: window.sidebarCollapsed ? 8 : 2 }

                Astrea.NavItem {
                    width: parent.width
                    label: window.sidebarCollapsed ? "" : "Wallpapers"
                    iconKey: "wallpaper"
                    selected: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Astrea.Theme.spacingLarge

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Astrea.Theme.spacingTiny

                    Text {
                        text: "Wallpapers"
                        color: Astrea.Theme.textPrimary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeHeader
                        font.weight: Astrea.Theme.fontWeightDemiBold
                        font.letterSpacing: 0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.errorText || window.statusText || "Manage wallpapers added to Astrea"
                        color: window.errorText ? Astrea.Theme.errorColor : Astrea.Theme.textSecondary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeNormal
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Astrea.Theme.spacingLarge

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 340
                        clip: true

                        GridView {
                            id: grid
                            anchors.fill: parent
                            anchors.margins: 2
                            cellWidth: Math.max(238, Math.floor(width / Math.max(1, Math.floor(width / 252))))
                            cellHeight: 184
                            clip: true
                            model: wallpaperModel
                            currentIndex: wallpaperModel.count > 0 ? 0 : -1
                            onCurrentIndexChanged: window.selectedIndex = currentIndex

                            delegate: Item {
                                id: tile
                                required property int index
                                required property string slug
                                required property string name
                                required property string thumbPath
                                required property int thumbMtime

                                width: grid.cellWidth
                                height: grid.cellHeight

                                Rectangle {
                                    anchors {
                                        fill: parent
                                        margins: 5
                                    }
                                    radius: 22
                                    color: tile.index === grid.currentIndex
                                        ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.16)
                                        : (tileHover.hovered ? Astrea.Theme.cardBg : "transparent")
                                    border.width: tile.index === grid.currentIndex ? 1 : 0
                                    border.color: tile.index === grid.currentIndex ? Astrea.Theme.accent : Astrea.Theme.cardBorder
                                    scale: tilePress.pressed ? 0.985 : 1
                                    layer.enabled: tile.index === grid.currentIndex || tileHover.hovered
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(0, 0, 0, 0.42)
                                        shadowBlur: 0.62
                                        shadowVerticalOffset: 8
                                    }

                                    Behavior on color { ColorAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }

                                    HoverHandler { id: tileHover }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: Astrea.Theme.spacingSmall

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 130
                                            radius: 18
                                            color: Astrea.Theme.cardBg
                                            border.width: 1
                                            border.color: Astrea.Theme.cardBorder
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: window.fileUrl(tile.thumbPath, tile.thumbMtime)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: false
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: tile.name
                                            color: Astrea.Theme.textPrimary
                                            font.family: Astrea.Theme.fontFamily
                                            font.pixelSize: Astrea.Theme.fontSizeNormal
                                            font.weight: Astrea.Theme.fontWeightMedium
                                            font.letterSpacing: 0
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: tilePress
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: grid.currentIndex = tile.index
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: wallpaperModel.count === 0
                            text: "No added wallpapers"
                            color: Astrea.Theme.textSecondary
                            font.family: Astrea.Theme.fontFamily
                            font.pixelSize: Astrea.Theme.fontSizeLarge
                        }
                    }

                    Astrea.FormCard {
                        Layout.preferredWidth: 360
                        Layout.alignment: Qt.AlignTop
                        margins: Astrea.Theme.spacingLarge
                        spacing: Astrea.Theme.spacingMedium

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 214
                            radius: 22
                            color: Astrea.Theme.cardBg
                            border.width: 1
                            border.color: Astrea.Theme.cardBorder
                            clip: true
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.50)
                                shadowBlur: 0.72
                                shadowVerticalOffset: 10
                            }

                            Image {
                                anchors.fill: parent
                                source: window.selectedItem ? window.fileUrl(window.selectedItem.wallpaperPath, Date.now()) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !window.selectedItem
                                text: "No selection"
                                color: Astrea.Theme.textSecondary
                                font.family: Astrea.Theme.fontFamily
                                font.pixelSize: Astrea.Theme.fontSizeNormal
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.selectedItem ? window.selectedItem.slug : "No selection"
                            color: Astrea.Theme.textSecondary
                            font.family: Astrea.Theme.fontFamily
                            font.pixelSize: Astrea.Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: Astrea.Theme.controlRadius
                            color: Astrea.Theme.cardBg
                            border.width: 1
                            border.color: nameInput.activeFocus ? Astrea.Theme.accent : Astrea.Theme.cardBorder

                            TextInput {
                                id: nameInput
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                enabled: !!window.selectedItem
                                text: window.selectedItem ? window.selectedItem.name : ""
                                color: Astrea.Theme.textPrimary
                                selectionColor: Astrea.Theme.accent
                                selectedTextColor: Astrea.Theme.accentForeground
                                font.family: Astrea.Theme.fontFamily
                                font.pixelSize: Astrea.Theme.fontSizeNormal
                                font.letterSpacing: 0
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                cursorVisible: activeFocus
                                onAccepted: window.renameSelected()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Astrea.Theme.spacing

                            Astrea.Button {
                                Layout.fillWidth: true
                                text: "Rename"
                                enabled: !!window.selectedItem
                                onClicked: window.renameSelected()
                            }

                            Astrea.Button {
                                Layout.fillWidth: true
                                text: "Delete"
                                danger: true
                                enabled: !!window.selectedItem
                                onClicked: window.requestDeleteSelected()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Astrea.Theme.cardBorder
                        }

                        Astrea.Button {
                            Layout.fillWidth: true
                            text: "Set as wallpaper"
                            primary: true
                            enabled: !!window.selectedItem
                            onClicked: window.applyTo("wallpaper")
                        }

                        Astrea.Button {
                            Layout.fillWidth: true
                            text: "Set as lockscreen"
                            enabled: !!window.selectedItem
                            onClicked: window.applyTo("lockscreen")
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.errorText
                            visible: !!window.errorText
                            color: Astrea.Theme.errorColor
                            font.family: Astrea.Theme.fontFamily
                            font.pixelSize: Astrea.Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: confirmDelete
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: parent
        width: 360
        padding: 0

        background: Rectangle {
            radius: Astrea.Theme.cardRadius
            color: Astrea.Theme.popupBg
            border.width: 1
            border.color: Astrea.Theme.cardBorder
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Astrea.Theme.spacingLarge
            spacing: Astrea.Theme.spacingMedium

            Text {
                Layout.fillWidth: true
                text: "Delete " + window.pendingName + "?"
                color: Astrea.Theme.textPrimary
                font.family: Astrea.Theme.fontFamily
                font.pixelSize: Astrea.Theme.fontSizeTitle
                font.weight: Astrea.Theme.fontWeightDemiBold
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "This removes it from the managed wallpaper library."
                color: Astrea.Theme.textSecondary
                font.family: Astrea.Theme.fontFamily
                font.pixelSize: Astrea.Theme.fontSizeNormal
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Astrea.Theme.spacing

                Astrea.Button {
                    Layout.fillWidth: true
                    text: "Cancel"
                    onClicked: confirmDelete.close()
                }

                Astrea.Button {
                    Layout.fillWidth: true
                    text: "Delete"
                    danger: true
                    primary: true
                    onClicked: {
                        confirmDelete.close()
                        window.deletePending()
                    }
                }
            }
        }
    }
}
