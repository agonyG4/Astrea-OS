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
    readonly property real pageRightGutter: 28

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
    readonly property string wpName_f:     _prefsBase + "/wallpaper/wallpaper_name.txt"
    readonly property string transFil:     _prefsBase + "/wallpaper_transition.txt"
    readonly property string userDir:      _userBase + "/wallpapers"
    readonly property string dynamicDir:   _featureBase + "/library/dynamic"
    readonly property string landscapeDir: _featureBase + "/library/landscapes"
    readonly property string imgCache:    _scripts + "/img_cache.py"
    readonly property string _thumbPath:   _prefsBase + "/wallpaper/wallpaper_thumb.jpg"

    property string wpThumb: "file://" + _thumbPath + "?t=" + Date.now()
    property int    selTrans: 0
    property string wpName:   "My Wallpaper"
    property string _picked:  ""
    property string _scanBuf: ""
    property int    _nameIdx: 0

    readonly property var transitions: [
        {l:"Simple",t:"simple"},{l:"Fade",t:"fade"},{l:"Left",t:"left"},
        {l:"Right",t:"right"},{l:"Top",t:"top"},{l:"Bottom",t:"bottom"},
        {l:"Wipe",t:"wipe"},{l:"Wave",t:"wave"},{l:"Grow",t:"grow"},
        {l:"Center",t:"center"},{l:"Outer",t:"outer"},{l:"Any",t:"any"},{l:"Random",t:"random"}
    ]

    function _reloadThumb() {
        wpThumb = ""
        thumbReloadTimer.restart()
    }

    Timer {
        id: thumbReloadTimer
        interval: 400
        repeat: false
        onTriggered: root.wpThumb = "file://" + root._thumbPath + "?t=" + Date.now()
    }

    ListModel { id: userModel }
    ListModel { id: dynamicModel }
    ListModel { id: landscapeModel }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function applyWallpaper(src, name, thumbSrc) {
        wpName = name
        saveNameProc.write(name)
        awwwProc.run(src)

        if (thumbSrc) {
            wpThumb = "file://" + thumbSrc + "?t=" + Date.now()
            copyThumbProc.run(thumbSrc)
        } else {
            thumbWallpaperProc.running = false
            Qt.callLater(() => thumbWallpaperProc.running = true)
        }
    }

    property var    _targetModel: null
    property string _targetDir:   ""
    property var    _scanQueue:   []

    function scanAll() {
        _scanQueue = [
            { dir: userDir, model: userModel },
            { dir: dynamicDir, model: dynamicModel },
            { dir: landscapeDir, model: landscapeModel }
        ]
        _checkNextScan()
    }

    function _checkNextScan() {
        if (_scanQueue.length > 0) {
            let next = _scanQueue.shift()
            _scanDir(next.dir, next.model)
        }
    }

    function _scanDir(dir, model) {
        _scanBuf = ""
        _targetModel = model
        _targetDir   = dir
        scanProc.sh("ls " + JSON.stringify(dir) + " 2>/dev/null")
    }

    function _readNextName() {
        if (!_targetModel || _nameIdx >= _targetModel.count) {
            _checkNextScan()
            return
        }
        let e = _targetModel.get(_nameIdx)
        nameReadProc.targetIndex = _nameIdx
        nameReadProc.sh(e.namePath)
    }

    // ── Processes ─────────────────────────────────────────────────────────────

    Process {
        id: saveNameProc
        running: false
        function write(name) {
            command = ["sh", "-c",
                "printf '%s\n' " + JSON.stringify(name) +
                " | tee " + JSON.stringify(root.wpName_f) + " > /dev/null"]
            running = false
            running = true
        }
    }

    Process {
        id: saveTransProc; running: false
        function run(idx) {
            command = ["sh","-c","printf '%s' "+idx+" > "+root.transFil]
            running = false
            running = true
        }
    }

    Process {
        id: initProc
        running: false
        command: ["sh","-c",
            "cat "+JSON.stringify(root.wpName_f)+" 2>/dev/null; echo '---'; cat "+JSON.stringify(root.transFil)+" 2>/dev/null"]
        property bool pastSep: false
        stdout: SplitParser {
            onRead: (l) => {
                if (l.trim() === "---") { initProc.pastSep = true; return }
                if (!initProc.pastSep) {
                    if (l.trim()) root.wpName = l.trim()
                } else {
                    let i = parseInt(l.trim())
                    if (!isNaN(i) && i >= 0 && i < root.transitions.length)
                        root.selTrans = i
                }
            }
        }
        onRunningChanged: { if (!running) pastSep = false }
    }

    Process {
        id: awwwProc; running: false
        function run(src) {
            command = ["awww","img",src,
                "--transition-type", root.transitions[root.selTrans].t,
                "--transition-duration","1.5","--transition-fps","60"]
            running = false
            running = true
        }
    }

    Process {
        id: pickerProc; running: false
        command: ["zenity","--file-selection","--title=Choose Wallpaper",
                  "--file-filter=Images | *.jpg *.jpeg *.png *.webp *.bmp *.tiff"]
        stdout: SplitParser { onRead: (l) => root._picked = l.trim() }
        onExited: (code) => { if (code===0 && root._picked) nameDialog.open() }
    }

    Process {
        id: copyApplyProc; running: false
        function run(src) {
            command = ["cp","--",src,root.wpFull]
            running = false
            running = true
        }
        onExited: (code) => {
            if (code===0) root.applyWallpaper(root.wpFull, root._nameInput, "")
            root._picked = ""
        }
    }

    property string _nameInput: ""

    Process {
        id: thumbWallpaperProc
        command: ["python3", root.imgCache, "--only-wallpaper"]
        running: false
        onExited: () => root._reloadThumb()
    }

    Process {
        id: copyThumbProc; running: false
        function run(src) {
            command = ["cp","--",src,root._thumbPath]
            running = false
            running = true
        }
    }

    Process {
        id: userPickerProc; running: false
        command: ["zenity","--file-selection","--title=Add User Wallpaper",
                  "--file-filter=Images | *.jpg *.jpeg *.png *.webp *.bmp *.tiff"]
        stdout: SplitParser { onRead: (l) => root._picked = l.trim() }
        onExited: (code) => { if (code===0 && root._picked) userNameDialog.open() }
    }

    Process {
        id: userCopyProc; running: false
        property string pendingSlug: ""
        onExited: (code) => {
            if (code===0 && pendingSlug) {
                userThumbProc.slug = pendingSlug
                userThumbProc.running = false
                Qt.callLater(() => userThumbProc.running = true)
            } else {
                root._picked = ""
            }
        }
    }

    Process {
        id: userThumbProc; running: false
        property string slug: ""
        command: ["python3", root.imgCache, "--slug", slug]
        onExited: () => {
            root._picked = ""
            root.scanAll()
        }
    }

    // ── Scan / leitura de nomes ───────────────────────────────────────────────

    Process {
        id: scanProc; running: false
        property string targetModel: "user"
        property string targetDir:   root.userDir
        function sh(cmd) { command=["sh","-c",cmd]; running=false; running=true }
        stdout: SplitParser {
            onRead: (l) => { if (l.trim()) root._scanBuf += (root._scanBuf?"|\n":"") + l.trim() }
        }
        onExited: () => {
            if (!_targetModel) return
            _targetModel.clear()
            if (root._scanBuf) {
                for (let slug of root._scanBuf.split("|\n")) {
                    if (!slug) continue
                    _targetModel.append({
                        slug,
                        name:     slug.replace(/_/g," "),
                        imgPath:  "file://"+_targetDir+"/"+slug+"/thumb.jpg",
                        namePath: _targetDir+"/"+slug+"/name.txt"
                    })
                }
                root._nameIdx = 0
                root._readNextName()
            } else {
                root._checkNextScan()
            }
            root._scanBuf = ""
        }
    }

    Process {
        id: nameReadProc; running: false
        property int    targetIndex: 0
        property string targetModel: "user"
        function sh(path) { command=["cat",path]; running=false; running=true }
        stdout: SplitParser {
            onRead: (l) => {
                if (l.trim() && root._targetModel && nameReadProc.targetIndex < root._targetModel.count)
                    root._targetModel.setProperty(nameReadProc.targetIndex, "name", l.trim())
            }
        }
        onExited: () => { root._nameIdx++; root._readNextName() }
    }

    // ── Init ──────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        initProc.running = true
        root.wpThumb = ""
        Qt.callLater(() => root.wpThumb = "file://" + root._thumbPath)
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

                Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.name_this_wallpaper"]) || "Name this wallpaper"); font.pixelSize: 15; font.weight: Font.Medium; color: root.textPrimary }

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
            root._nameInput = name
            copyApplyProc.run(root._picked)
        }
    }

    NameDialog {
        id: userNameDialog
        placeholder: "e.g. Mountain Sunset"
        onConfirmed: (name) => {
            let slug = name.replace(/ /g,"_")
            let dest = root.userDir + "/" + slug
            userCopyProc.pendingSlug = slug
            userCopyProc.command = ["sh","-c",
                "mkdir -p "+JSON.stringify(dest)+
                " && cp -- "+JSON.stringify(root._picked)+" "+JSON.stringify(dest+"/wallpaper.jpg")+
                " && printf '%s' "+JSON.stringify(name)+" > "+JSON.stringify(dest+"/name.txt")]
            userCopyProc.running = false
            userCopyProc.running = true
        }
    }

    // ── WallpaperGrid component ───────────────────────────────────────────────
    // Reutilizável pelas 3 seções — só muda model e dir

    component WallpaperGrid: Grid {
        id: wg
        property var   wpModel: null
        property string wpDir:  ""
        property real sideInset: 12
        width: parent ? parent.width : 0
        columns: 3; spacing: 8
        visible: wpModel && wpModel.count > 0

        Repeater {
            model: wg.wpModel
            Rectangle {
                id: tile
                required property string name
                required property string imgPath
                required property string slug
                width: (wg.width - (wg.sideInset * 2) - (wg.spacing * (wg.columns - 1))) / wg.columns
                height: width * 0.6
                x: (index % wg.columns) * (width + wg.spacing) + wg.sideInset
                radius: 8; clip: true; color: "#0d1b2a"
                border.width: 1; border.color: tma.containsMouse ? root.accent : root.cardBorder
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Image {
                    anchors.fill: parent; source: tile.imgPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; smooth: false; mipmap: true; cache: false
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 28; color: Qt.rgba(0,0,0,0.55)
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 8; color: parent.color }
                    Text {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 6 }
                        text: tile.name; font.pixelSize: 11; font.weight: Font.Medium; color: "#fff"; elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let thumbSrc = wg.wpDir + "/" + tile.slug + "/thumb.jpg"
                        root.applyWallpaper(wg.wpDir + "/" + tile.slug + "/wallpaper.jpg", tile.name, thumbSrc)
                    }
                }
            }
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    Item {
        anchors.fill: parent

        ColumnLayout {
            anchors {
                fill: parent
                margins: 28
            }
            spacing: 0

            SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.current"]) || "CURRENT"); Layout.bottomMargin: 12; textSecondary: root.textSecondary }

            Rectangle {
                Layout.fillWidth: true; Layout.bottomMargin: 8
                Layout.rightMargin: root.pageRightGutter
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
                            asynchronous: true; smooth: false; mipmap: true; cache: false

                            layer.enabled: true
                            layer.smooth: false
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: thumbMask
                                maskThresholdMin: 0.4
                                maskSpreadAtMin: 0.6
                            }

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 4
                                visible: thumbImg.status === Image.Error || thumbImg.status === Image.Null
                                Text {
                                    Layout.alignment: Qt.AlignCenter
                                    text: "\uf03e"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: root.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignCenter
                                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.preview_fail"]) || "Preview Fail"); font.pixelSize: 10; font.weight: Font.Medium; color: root.textSecondary
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
                                    anchors.horizontalCenter: parent.horizontalCenter; text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.change"]) || "Change")
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

                        Text { text: root.wpName; font.pixelSize: 15; font.weight: Font.Medium
                            color: root.textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.show_on_all_workspaces"]) || "Show on all workspaces"); font.pixelSize: 13; color: root.textPrimary; Layout.fillWidth: true }
                            ToggleSwitch {
                                id: wsToggle
                                checked: true
                                onToggled: checked = !checked
                            }
                        }

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
                Layout.rightMargin: root.pageRightGutter
                radius: 12; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                implicitHeight: tRow.implicitHeight
                SettingRow {
                    id: tRow; anchors.left: parent.left; anchors.right: parent.right
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.label.transition"]) || "Transition"); sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.sublabel.awww_wallpaper_animation"]) || "awww wallpaper animation"); isLast: true
                    textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                    SelectButton {
                        implicitWidth: 140; label: root.transitions[root.selTrans].l
                        options: root.transitions.map(t=>t.l); selectedIndex: root.selTrans
                        onSelected: (i) => { root.selTrans=i; saveTransProc.run(i) }
                        accent: root.accent; textPrimary: root.textPrimary
                        textSecondary: root.textSecondary; popupBg: root.popupBg
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.rightMargin: root.pageRightGutter
                Layout.bottomMargin: 24
                height: 1
                color: root.cardBorder
            }

            SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.wallpaper_library"]) || "WALLPAPER LIBRARY"); Layout.bottomMargin: 12; textSecondary: root.textSecondary }

            Rectangle {
                Layout.fillWidth: true
                Layout.rightMargin: root.pageRightGutter
                radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder; implicitHeight: libCol.implicitHeight

                ColumnLayout {
                    id: libCol
                    anchors.left: parent.left; anchors.right: parent.right; spacing: 0

                    // ── Dynamic Wallpapers ────────────────────────────────────
                    ColumnLayout {
                        id: dynamicSect; Layout.fillWidth: true; spacing: 0
                        property bool open: true

                        RowLayout {
                            Layout.fillWidth: true; Layout.margins: 16; Layout.topMargin: 12; Layout.bottomMargin: 12; spacing: 8
                            Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.dynamic_wallpapers"]) || "Dynamic Wallpapers"); font.pixelSize: 13; font.weight: Font.Medium; color: root.textPrimary; Layout.fillWidth: true }
                            Item { width: 16; height: 26
                                Text { anchors.centerIn: parent; text: dynamicSect.open?"▾":"▸"; font.pixelSize: 11; color: root.textSecondary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dynamicSect.open=!dynamicSect.open }
                            }
                        }

                        Item {
                            visible: dynamicSect.open; Layout.fillWidth: true
                            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 14
                            implicitHeight: dynamicModel.count ? dynGrid.implicitHeight : dynEmpty.implicitHeight

                            Text { id: dynEmpty; anchors.horizontalCenter: parent.horizontalCenter
                                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.no_wallpapers_found"]) || "No wallpapers found"); font.pixelSize: 12; color: root.textSecondary
                                visible: !dynamicModel.count }

                            WallpaperGrid {
                                id: dynGrid; width: parent.width
                                wpModel: dynamicModel; wpDir: root.dynamicDir
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cardBorder }

                    // ── User Wallpapers ───────────────────────────────────────
                    ColumnLayout {
                        id: userSect; Layout.fillWidth: true; spacing: 0
                        property bool open: true

                        RowLayout {
                            Layout.fillWidth: true; Layout.margins: 16; Layout.topMargin: 12; Layout.bottomMargin: 12; spacing: 8
                            Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.user_wallpapers"]) || "User Wallpapers"); font.pixelSize: 13; font.weight: Font.Medium; color: root.textPrimary; Layout.fillWidth: true }
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
                                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.no_wallpapers_found"]) || "No wallpapers found"); font.pixelSize: 12; color: root.textSecondary
                                visible: !userModel.count }

                            WallpaperGrid {
                                id: ugrid; width: parent.width
                                wpModel: userModel; wpDir: root.userDir
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cardBorder }

                    // ── Landscapes ────────────────────────────────────────────
                    ColumnLayout {
                        id: landscapeSect; Layout.fillWidth: true; spacing: 0
                        property bool open: true

                        RowLayout {
                            Layout.fillWidth: true; Layout.margins: 16; Layout.topMargin: 12; Layout.bottomMargin: 12; spacing: 8
                            Text { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.landscapes"]) || "Landscapes"); font.pixelSize: 13; font.weight: Font.Medium; color: root.textPrimary; Layout.fillWidth: true }
                            Item { width: 16; height: 26
                                Text { anchors.centerIn: parent; text: landscapeSect.open?"▾":"▸"; font.pixelSize: 11; color: root.textSecondary }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: landscapeSect.open=!landscapeSect.open }
                            }
                        }

                        Item {
                            visible: landscapeSect.open; Layout.fillWidth: true
                            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 14
                            implicitHeight: landscapeModel.count ? lsGrid.implicitHeight : lsEmpty.implicitHeight

                            Text { id: lsEmpty; anchors.horizontalCenter: parent.horizontalCenter
                                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.paper.text.no_wallpapers_found"]) || "No wallpapers found"); font.pixelSize: 12; color: root.textSecondary
                                visible: !landscapeModel.count }

                            WallpaperGrid {
                                id: lsGrid; width: parent.width
                                wpModel: landscapeModel; wpDir: root.landscapeDir
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 28 }
        }
    }
}
