import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import QtQuick.Effects
import "../../AstreaI18n" as AstreaI18n

Item {
    id: root

    // ── Signal de Navegação ───────────────────────────────────────────────
    signal navigateTo(string page)

    readonly property color accent: Theme.accent
    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color popupBg: Theme.popupBg

    // ── Constantes e Caminhos ────────────────────────────────────────────────
    readonly property string _featureBase: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Features/Paper"
    readonly property string _dataBase:    Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")
    readonly property string _configBaseRoot: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string _userBase:    _dataBase + "/AstreaOS/user"
    readonly property string _configBase:  _configBaseRoot + "/AstreaOS/user"
    readonly property string _prefsBase:   _configBase + "/paper"
    readonly property string _scripts:     (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/wallpaper"
    readonly property string wpFull:       _prefsBase + "/wallpaper/wallpaper.jpg"
    readonly property string transFil:     _prefsBase + "/wallpaper_transition.txt"
    readonly property string userDir:      _userBase + "/wallpapers"
    readonly property string dynamicDir:   _featureBase + "/library/dynamic"
    readonly property string landscapesDir:_featureBase + "/library/landscapes"
    readonly property string wallpaperManager: _scripts + "/wallpaper_manager.py"
    readonly property string _thumbPath: _prefsBase + "/wallpaper/wallpaper_thumb.jpg"

    property string currentPreviewPath: _thumbPath
    property int currentPreviewVersion: 0
    property string wpThumb: _fileUrl(currentPreviewPath, currentPreviewVersion)
    property int    selTrans: 0
    property string wpName:   ""
    property string _picked:  ""
    property bool useBlurredWallpaper: false

    readonly property var transitions: [
        {l:"Simple",t:"simple"},{l:"Fade",t:"fade"},{l:"Left",t:"left"},
        {l:"Right",t:"right"},{l:"Top",t:"top"},{l:"Bottom",t:"bottom"},
        {l:"Wipe",t:"wipe"},{l:"Wave",t:"wave"},{l:"Grow",t:"grow"},
        {l:"Center",t:"center"},{l:"Outer",t:"outer"},{l:"Any",t:"any"},{l:"Random",t:"random"}
    ]

    function _fileUrl(path, version) {
        if (!path)
            return ""
        return encodeURI("file://" + path) + "?t=" + version
    }

    function _refreshPreviewNow() {
        root.wpThumb = root._fileUrl(root.currentPreviewPath, root.currentPreviewVersion)
    }

    ListModel { id: userModel }
    ListModel { id: dynamicModel }
    ListModel { id: landscapesModel }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _runProcess(proc) {
        proc.running = false
        Qt.callLater(() => proc.running = true)
    }

    function _parseJson(raw, label) {
        try {
            return JSON.parse(raw)
        } catch (err) {
            console.log("Wallpaper " + label + " parse failed:", err, raw)
            return null
        }
    }

    function _applyState(payload, preservePreview) {
        if (!payload)
            return
        if (payload.name !== undefined)
            root.wpName = payload.name
        if (payload.transitionIndex !== undefined)
            root.selTrans = payload.transitionIndex
        if (payload.useBlurred !== undefined)
            root.useBlurredWallpaper = payload.useBlurred
        if (!preservePreview) {
            if (payload.previewPath)
                root.currentPreviewPath = payload.previewPath
            else if (payload.thumbPath)
                root.currentPreviewPath = payload.thumbPath
            else if (payload.wallpaperPath)
                root.currentPreviewPath = payload.wallpaperPath
            if (payload.previewMtime !== undefined)
                root.currentPreviewVersion = payload.previewMtime
            else
                root.currentPreviewVersion = Date.now()
            root._refreshPreviewNow()
        }
    }

    function _setModelItems(model, items) {
        model.clear()
        for (let item of items) {
            model.append({
                slug: item.slug,
                name: item.name,
                imgPath: root._fileUrl(item.thumbPath, item.thumbMtime || 0),
                wallpaperPath: item.wallpaperPath,
                blurredPath: item.blurredPath || "",
                baseDir: item.baseDir
            })
        }
    }

    function _appendModelItem(model, item) {
        if (!item)
            return
        model.append({
            slug: item.slug,
            name: item.name,
            imgPath: root._fileUrl(item.thumbPath, item.thumbMtime || 0),
            wallpaperPath: item.wallpaperPath,
            blurredPath: item.blurredPath || "",
            baseDir: item.baseDir
        })
    }

    function applyWallpaper(src, name, previewUrl) {
        wpName = name
        if (previewUrl)
            root.wpThumb = previewUrl
        wallpaperApplyProc.sourcePath = src
        wallpaperApplyProc.wallpaperName = name
        wallpaperApplyProc.transitionIndex = root.selTrans
        _runProcess(wallpaperApplyProc)
    }

    function scanAll() {
        _runProcess(scanProc)
    }

    function loadState() {
        _runProcess(stateProc)
    }

    // ── Processes ─────────────────────────────────────────────────────────────

    Process {
        id: stateProc
        running: false
        property string _json: ""
        command: ["python3", root.wallpaperManager, "state", "--scope", "wallpaper"]
        stdout: SplitParser { onRead: (line) => stateProc._json += line }
        onExited: (code) => {
            if (code === 0) {
                let payload = root._parseJson(stateProc._json, "state")
                root._applyState(payload, false)
            }
            stateProc._json = ""
        }
    }

    Process {
        id: transitionProc
        running: false
        function run(idx) {
            command = ["python3", root.wallpaperManager, "set-transition", "--index", String(idx)]
            root._runProcess(transitionProc)
        }
    }

    Process {
        id: blurredProc
        running: false
        property string _json: ""
        function run(enabled) {
            command = [
                "python3", root.wallpaperManager, "set-blurred",
                "--enabled", enabled ? "1" : "0"
            ]
            root._runProcess(blurredProc)
        }
        stdout: SplitParser { onRead: (line) => blurredProc._json += line }
        onExited: (code) => {
            if (code === 0) {
                let payload = root._parseJson(blurredProc._json, "set-blurred")
                root._applyState(payload, false)
            }
            blurredProc._json = ""
        }
    }

    Process {
        id: wallpaperApplyProc
        running: false
        property string sourcePath: ""
        property string wallpaperName: ""
        property int transitionIndex: 0
        property string _json: ""
        command: [
            "python3", root.wallpaperManager, "apply",
            "--scope", "wallpaper",
            "--src", sourcePath,
            "--name", wallpaperName,
            "--transition-index", String(transitionIndex)
        ]
        stdout: SplitParser { onRead: (line) => wallpaperApplyProc._json += line }
        onExited: (code) => {
            if (code === 0) {
                let payload = root._parseJson(wallpaperApplyProc._json, "apply")
                root._applyState(payload, true)
            }
            wallpaperApplyProc._json = ""
        }
    }

    Process {
        id: pickerProc
        running: false
        command: ["zenity","--file-selection","--title=Choose Wallpaper",
                  "--file-filter=Images | *.jpg *.jpeg *.png *.webp *.bmp *.tiff"]
        stdout: SplitParser { onRead: (l) => root._picked = l.trim() }
        onExited: (code) => { if (code===0 && root._picked) nameDialog.open() }
    }

    Process {
        id: userPickerProc
        running: false
        command: ["zenity","--file-selection","--title=Add User Wallpaper",
                  "--file-filter=Images | *.jpg *.jpeg *.png *.webp *.bmp *.tiff"]
        stdout: SplitParser { onRead: (l) => root._picked = l.trim() }
        onExited: (code) => { if (code===0 && root._picked) userNameDialog.open() }
    }

    Process {
        id: userAddProc
        running: false
        property string sourcePath: ""
        property string wallpaperName: ""
        property string _json: ""
        command: [
            "python3", root.wallpaperManager, "add-user",
            "--src", sourcePath,
            "--name", wallpaperName
        ]
        stdout: SplitParser { onRead: (line) => userAddProc._json += line }
        onExited: () => {
            let payload = root._parseJson(userAddProc._json, "add-user")
            if (payload && payload.item)
                root._appendModelItem(userModel, payload.item)
            else
                root.scanAll()
            root._picked = ""
            userAddProc._json = ""
        }
    }

    Process {
        id: scanProc
        running: false
        property string _json: ""
        command: ["python3", root.wallpaperManager, "scan-library"]
        stdout: SplitParser { onRead: (line) => scanProc._json += line }
        onExited: () => {
            let payload = root._parseJson(scanProc._json, "scan")
            if (payload) {
                root._setModelItems(userModel, payload.user || [])
                root._setModelItems(dynamicModel, payload.dynamic || [])
                root._setModelItems(landscapesModel, payload.landscapes || [])
            }
            scanProc._json = ""
        }
    }

    // ── Init ──────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        root.loadState()
        Qt.callLater(root.scanAll)
    }

    // ── Dialogs ───────────────────────────────────────────────────────────────

    component NameDialog: Rectangle {
        id: dlg
        anchors.fill: parent
        color: Qt.rgba(0,0,0,0.6)
        visible: false
        z: 100

        property string placeholder: "e.g. Tokyo Night"
        signal confirmed(string name)

        function open() { inp.text=""; visible=true; inp.forceActiveFocus() }
        function _ok() { confirmed(inp.text.trim() || "Wallpaper"); visible=false }

        MouseArea { anchors.fill: parent; onClicked: dlg.visible=false }

        Rectangle {
            anchors.centerIn: parent; width: 320; radius: 14
            color: root.popupBg; border.width:1; border.color: root.cardBorder
            implicitHeight: dc.implicitHeight + 40
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: dc
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 16

                Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.name_this_wallpaper"]) || "Name this wallpaper"); font.pixelSize: 15; font.weight: Font.Medium; color: root.textPrimary }

                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8
                    color: Qt.rgba(1,1,1,0.06); border.width: 1
                    border.color: inp.activeFocus ? root.accent : root.cardBorder
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    TextInput {
                        id: inp
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 13; color: root.textPrimary; selectionColor: root.accent
                        Keys.onReturnPressed: dlg._ok()
                        Keys.onEscapePressed: dlg.visible=false
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            text: dlg.placeholder; font: inp.font; color: root.textSecondary
                            visible: !inp.text && !inp.activeFocus
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: [{t:"Cancel",accent:false},{t:"Confirm",accent:true}]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; height: 34; radius: 8
                            color: modelData.accent
                                ? (bma.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.82) : root.accent)
                                : (bma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                            border.width: modelData.accent ? 0 : 1; border.color: root.cardBorder
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 13
                                font.weight: modelData.accent ? Font.Medium : Font.Normal
                                color: modelData.accent ? Theme.accentForeground : root.textSecondary }
                            MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.accent ? dlg._ok() : (dlg.visible=false) }
                        }
                    }
                }
            }
        }
    }

    NameDialog {
        id: nameDialog
        placeholder: "e.g. Tokyo Night"
        onConfirmed: (name) => {
            root.applyWallpaper(root._picked, name)
            root._picked = ""
        }
    }

    NameDialog {
        id: userNameDialog
        placeholder: "e.g. Mountain Sunset"
        onConfirmed: (name) => {
            userAddProc.sourcePath = root._picked
            userAddProc.wallpaperName = name
            root._runProcess(userAddProc)
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    ScrollPage {
        anchors.fill: parent
        contentMargins: 28

        ColumnLayout {
            width: parent.width
            spacing: 0

            SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.current"]) || "CURRENT"); Layout.bottomMargin: 12; textSecondary: root.textSecondary }

            Rectangle {
                Layout.fillWidth: true; Layout.bottomMargin: 8
                radius: 12; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                implicitHeight: wpRow.implicitHeight + 32

                RowLayout {
                    id: wpRow
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 16

                    Item {
                        id: previewContainer
                        width: 180; height: 112

                        Rectangle {
                            anchors.fill: parent; radius: 14
                            color: root.cardBg
                            border.width: 1; border.color: root.cardBorder
                        }

                        Item {
                            id: thumbMask
                            anchors.fill: parent; visible: false
                            layer.enabled: true
                            Rectangle { anchors.fill: parent; radius: 14 }
                        }

                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: root.wpThumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: false; smooth: true; mipmap: true; cache: true
                            retainWhileLoading: true
                            sourceSize.width: width
                            sourceSize.height: height

                            layer.enabled: true
                            layer.smooth: true
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: thumbMask
                                maskThresholdMin: 0.4
                                maskSpreadAtMin: 0.6
                            }

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 4
                                visible: !!thumbImg.source && thumbImg.status === Image.Error
                                Text {
                                    Layout.alignment: Qt.AlignCenter
                                    text: "\uf03e"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: root.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignCenter
                                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.preview_fail"]) || "Preview Fail"); font.pixelSize: 10; font.weight: Font.Medium; color: root.textSecondary
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent; radius: 14
                            color: Qt.rgba(0,0,0, thMa.containsMouse ? 0.45 : 0)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Column {
                                anchors.centerIn: parent; spacing: 4; visible: thMa.containsMouse
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter; text: "\uf574"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: "#fff"
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter; text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.change"]) || "Change")
                                    font.pixelSize: 11; font.weight: Font.Medium; color: "#fff"
                                }
                            }
                        }

                        MouseArea {
                            id: thMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { pickerProc.running = false; pickerProc.running = true }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12

                        Text { text: root.wpName || "My Wallpaper"; font.pixelSize: 15; font.weight: Font.Medium
                            color: root.textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.show_on_all_workspaces"]) || "Show on all workspaces"); font.pixelSize: 13; color: root.textPrimary; Layout.fillWidth: true }
                            ToggleSwitch {
                                id: wsToggle
                                checked: true
                                onToggled: checked = !checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.use_blurred_wallpaper"]) || "Use blurred wallpaper"); font.pixelSize: 13; color: root.textPrimary; Layout.fillWidth: true }
                            ToggleSwitch {
                                checked: root.useBlurredWallpaper
                                onToggled: {
                                    root.useBlurredWallpaper = !root.useBlurredWallpaper
                                    blurredProc.run(root.useBlurredWallpaper)
                                }
                            }
                        }

                        // ── Botões Screensaver / Lockscreen ───────────────────
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: ["Screensaver", "Lockscreen"]
                                Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true; height: 30; radius: 8
                                    color: bma2.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                                    border.width: 1; border.color: root.cardBorder
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text { anchors.centerIn: parent; text: modelData
                                        font.pixelSize: 12; font.weight: Font.Medium; color: root.textPrimary }
                                    MouseArea {
                                        id: bma2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData === "Lockscreen")
                                                root.navigateTo("lockscreen")
                                            else if (modelData === "Screensaver")
                                                root.navigateTo("screensaver")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.bottomMargin: 28
                radius: 12; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                implicitHeight: tRow.implicitHeight
                SettingRow {
                    id: tRow; anchors.left: parent.left; anchors.right: parent.right
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.label.transition"]) || "Transition"); sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.sublabel.awww_wallpaper_animation"]) || "awww wallpaper animation"); isLast: true
                    textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                    SelectButton {
                        implicitWidth: 140; label: root.transitions[root.selTrans].l
                        options: root.transitions.map(t=>t.l); selectedIndex: root.selTrans
                        onSelected: (i) => { root.selTrans=i; transitionProc.run(i) }
                        accent: root.accent; textPrimary: root.textPrimary
                        textSecondary: root.textSecondary; popupBg: root.popupBg
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.bottomMargin: 24; height: 1; color: root.cardBorder }

            SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.wallpaper_library"]) || "WALLPAPER LIBRARY"); Layout.bottomMargin: 12; textSecondary: root.textSecondary }

            Rectangle {
                Layout.fillWidth: true; radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder; implicitHeight: libCol.implicitHeight

                ColumnLayout {
                    id: libCol
                    anchors.left: parent.left; anchors.right: parent.right; spacing: 0

                    LibSect {
                        Layout.fillWidth: true
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.label.dynamic_wallpapers"]) || "Dynamic Wallpapers")
                        model: dynamicModel
                        dir: dynamicDir
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cardBorder }

                    ColumnLayout {
                        id: userSect; Layout.fillWidth: true; spacing: 0
                        property bool open: true

                        RowLayout {
                            Layout.fillWidth: true; Layout.margins: 16; Layout.topMargin: 12; Layout.bottomMargin: 12; spacing: 8
                            Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.user_wallpapers"]) || "User Wallpapers"); font.pixelSize: 13; font.weight: Font.Medium; color: root.textPrimary; Layout.fillWidth: true }
                            Rectangle {
                                width: 26; height: 26; radius: 8
                                color: addMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15) : Qt.rgba(1,1,1,0.06)
                                border.width: 1; border.color: addMa.containsMouse ? root.accent : root.cardBorder
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; font.weight: Font.Light
                                    color: addMa.containsMouse ? root.accent : root.textSecondary
                                    Behavior on color { ColorAnimation { duration: 120 } } }
                                MouseArea {
                                    id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { userPickerProc.running = false; userPickerProc.running = true }
                                }
                            }
                            Item { width: 16; height: 26
                                Text { anchors.centerIn: parent; text: userSect.open?"▾":"▸"; font.pixelSize: 11; color: root.textSecondary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: userSect.open=!userSect.open }
                            }
                        }

                        Item {
                            visible: userSect.open; Layout.fillWidth: true
                            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 14
                            implicitHeight: userModel.count ? ugrid.implicitHeight : emptyLbl.implicitHeight

                            Text { id: emptyLbl; anchors.horizontalCenter: parent.horizontalCenter
                                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.no_wallpapers_found"]) || "No wallpapers found"); font.pixelSize: 12; color: root.textSecondary
                                visible: !userModel.count }

                            Grid {
                                id: ugrid; width: parent.width; columns: 3; spacing: 8; visible: userModel.count > 0
                                Repeater {
                                    model: userModel
                            Item {
                                id: tile
                                required property string name
                                required property string imgPath
                                required property string slug
                                required property string baseDir
                                required property string wallpaperPath
                                required property string blurredPath
                                width: (ugrid.width - 16) / 3; height: width * 0.6 + 28

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 6

                                    Rectangle {
                                        id: imgCont
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 14; color: "#0d1b2a"
                                        border.width: 1; border.color: tma.containsMouse ? root.accent : root.cardBorder
                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        Item {
                                            id: maskItem
                                            anchors.fill: parent; visible: false
                                            layer.enabled: true
                                            Rectangle { anchors.fill: parent; radius: 14 }
                                        }

                                        Image {
                                            anchors.fill: parent; source: tile.imgPath
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: false; smooth: true; mipmap: true; cache: true
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: maskItem
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: tile.name; font.pixelSize: 11; font.weight: Font.Medium; color: root.textPrimary; elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyWallpaper(tile.wallpaperPath, tile.name, tile.imgPath)
                                }
                            }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cardBorder }
                    LibSect {
                        Layout.fillWidth: true
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.label.landscapes"]) || "Landscapes")
                        model: landscapesModel
                        dir: landscapesDir
                    }
                }
            }

            Item { Layout.preferredHeight: 28 }
        }
    }

    // ── LibSect component ─────────────────────────────────────────────────────

    component LibSect: ColumnLayout {
        id: ls; spacing: 0
        property string label: ""
        property bool open: true
        property var model: null
        property string dir: ""

        RowLayout {
            Layout.fillWidth: true; Layout.margins: 16; Layout.topMargin: 12; Layout.bottomMargin: 12; spacing: 8
            Text { text: ls.label; font.pixelSize: 13; font.weight: Font.Medium; color: root.textPrimary; Layout.fillWidth: true }
            Item { width: 16; height: 26
                Text { anchors.centerIn: parent; text: ls.open?"▾":"▸"; font.pixelSize: 11; color: root.textSecondary }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ls.open=!ls.open }
            }
        }
        Item {
            visible: ls.open; Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 14
            implicitHeight: (ls.model && ls.model.count) ? ugrid_ls.implicitHeight : nf.implicitHeight

            Text { id: nf; anchors.horizontalCenter: parent.horizontalCenter; text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.wallpaper.text.no_wallpapers_found"]) || "No wallpapers found"); font.pixelSize: 12; color: root.textSecondary; visible: !(ls.model && ls.model.count) }

            Grid {
                id: ugrid_ls; width: parent.width; columns: 3; spacing: 8; visible: ls.model && ls.model.count > 0
                Repeater {
                    model: ls.model
                        Item {
                            id: tile_ls
                            required property string name
                            required property string imgPath
                            required property string slug
                            required property string baseDir
                            required property string wallpaperPath
                            required property string blurredPath
                            width: (ugrid_ls.width - 16) / 3; height: width * 0.6 + 28

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 6

                                Rectangle {
                                    id: imgCont_ls
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14; color: "#0d1b2a"
                                    border.width: 1; border.color: tma_ls.containsMouse ? root.accent : root.cardBorder
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    Item {
                                        id: maskItem_ls
                                        anchors.fill: parent; visible: false
                                        layer.enabled: true
                                        Rectangle { anchors.fill: parent; radius: 14 }
                                    }

                                    Image {
                                        anchors.fill: parent; source: tile_ls.imgPath
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: false; smooth: true; mipmap: true; cache: true
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: maskItem_ls
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: tile_ls.name; font.pixelSize: 11; font.weight: Font.Medium; color: root.textPrimary; elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: tma_ls; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyWallpaper(tile_ls.wallpaperPath, tile_ls.name, tile_ls.imgPath)
                            }
                        }
                }
            }
        }
    }
}
