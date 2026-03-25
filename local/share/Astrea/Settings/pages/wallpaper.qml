import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../components"
import QtQuick.Effects

Item {
    id: root

    // ── Signal de Navegação ───────────────────────────────────────────────
    signal navigateTo(string page)

    readonly property color accent:        "#0a84ff"
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSecondary: "#98989f"
    readonly property color cardBg:        Qt.rgba(1,1,1,0.05)
    readonly property color cardBorder:    Qt.rgba(1,1,1,0.08)
    readonly property color popupBg:       Qt.rgba(0.13,0.13,0.14,0.97)

    // ── Constantes e Caminhos ────────────────────────────────────────────────
    readonly property string _base:    Quickshell.env("HOME") + "/.local/share/Astrea/System/Paper"
    readonly property string wpFull:   _base + "/Wallpaper/wallpaper.jpg"
    readonly property string wpName_f: _base + "/Wallpaper/wallpaper_name.txt"
    readonly property string transFil: _base + "/wallpaper_transition.txt"
    readonly property string userDir:  _base + "/UserWallpapers"
    readonly property string imgCache: _base + "/scripts/img_cache.py"
    readonly property string _thumbPath: _base + "/Wallpaper/wallpaper_thumb.jpg"

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

    function scanUsers() {
        _scanBuf = ""
        scanProc.sh("ls " + JSON.stringify(userDir) + " 2>/dev/null")
    }

    function _readNextName() {
        if (_nameIdx >= userModel.count) return
        let e = userModel.get(_nameIdx)
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
        onRunningChanged: {
            if (!running) pastSep = false
        }
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
            root.scanUsers()
        }
    }

    // ── Scan / leitura de nomes ───────────────────────────────────────────────

    Process {
        id: scanProc; running: false
        function sh(cmd) { command=["sh","-c",cmd]; running=false; running=true }
        stdout: SplitParser {
            onRead: (l) => { if (l.trim()) root._scanBuf += (root._scanBuf?"|\n":"") + l.trim() }
        }
        onExited: () => {
            userModel.clear()
            if (root._scanBuf) {
                for (let slug of root._scanBuf.split("|\n")) {
                    if (!slug) continue
                    userModel.append({
                        slug,
                        name:     slug.replace(/_/g," "),
                        imgPath:  "file://"+root.userDir+"/"+slug+"/thumb.jpg",
                        namePath: root.userDir+"/"+slug+"/name.txt"
                    })
                }
                root._nameIdx = 0
                root._readNextName()
            }
            root._scanBuf = ""
        }
    }

    Process {
        id: nameReadProc; running: false
        property int targetIndex: 0
        function sh(path) { command=["cat",path]; running=false; running=true }
        stdout: SplitParser {
            onRead: (l) => {
                if (l.trim() && nameReadProc.targetIndex < userModel.count)
                    userModel.setProperty(nameReadProc.targetIndex, "name", l.trim())
            }
        }
        onExited: () => { root._nameIdx++; root._readNextName() }
    }

    // ── Init ──────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        initProc.running = true
        root.wpThumb = ""
        Qt.callLater(() => root.wpThumb = "file://" + root._thumbPath)
        Qt.callLater(root.scanUsers)
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

                Text { text: "Name this wallpaper"; font.pixelSize: 15; font.weight: Font.Medium; color: root.textPrimary }

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
                                ? (bma.containsMouse ? Qt.rgba(10/255,132/255,255/255,0.8) : root.accent)
                                : (bma.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                            border.width: modelData.accent ? 0 : 1; border.color: root.cardBorder
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 13
                                font.weight: modelData.accent ? Font.Medium : Font.Normal
                                color: modelData.accent ? "#fff" : root.textSecondary }
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

    // ── UI ────────────────────────────────────────────────────────────────────

    ScrollView {
        anchors.fill: parent; anchors.margins: 28
        contentWidth: availableWidth; clip: true

        ColumnLayout {
            width: parent.width; spacing: 0

            SectionHeader { text: "CURRENT"; Layout.bottomMargin: 12; textSecondary: root.textSecondary }

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
                            asynchronous: true; smooth: true; mipmap: true; cache: false

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
                                visible: thumbImg.status === Image.Error || thumbImg.status === Image.Null
                                Text {
                                    Layout.alignment: Qt.AlignCenter
                                    text: "\uf03e"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: root.textSecondary
                                }
                                Text {
                                    Layout.alignment: Qt.AlignCenter
                                    text: "Preview Fail"; font.pixelSize: 10; font.weight: Font.Medium; color: root.textSecondary
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
                                    anchors.horizontalCenter: parent.horizontalCenter; text: "Change"
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
                            Text { text: "Show on all workspaces"; font.pixelSize: 13; color: root.textPrimary; Layout.fillWidth: true }
                            Rectangle {
                                id: wsToggle; width: 36; height: 20; radius: 10; property bool on: true
                                color: on ? root.accent : Qt.rgba(1,1,1,0.18)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle {
                                    width: 14; height: 14; radius: 7; color: "#fff"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.on ? parent.width-width-3 : 3
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.on=!parent.on }
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
                    label: "Transition"; sublabel: "awww wallpaper animation"; isLast: true
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

            Rectangle { Layout.fillWidth: true; Layout.bottomMargin: 24; height: 1; color: root.cardBorder }

            SectionHeader { text: "WALLPAPER LIBRARY"; Layout.bottomMargin: 12; textSecondary: root.textSecondary }

            Rectangle {
                Layout.fillWidth: true; radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder; implicitHeight: libCol.implicitHeight

                ColumnLayout {
                    id: libCol
                    anchors.left: parent.left; anchors.right: parent.right; spacing: 0

                    LibSect { Layout.fillWidth: true; label: "Dynamic Wallpapers" }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cardBorder }

                    ColumnLayout {
                        id: userSect; Layout.fillWidth: true; spacing: 0
                        property bool open: true

                        RowLayout {
                            Layout.fillWidth: true; Layout.margins: 16; Layout.topMargin: 12; Layout.bottomMargin: 12; spacing: 8
                            Text { text: "User Wallpapers"; font.pixelSize: 13; font.weight: Font.Medium; color: root.textPrimary; Layout.fillWidth: true }
                            Rectangle {
                                width: 26; height: 26; radius: 8
                                color: addMa.containsMouse ? Qt.rgba(10/255,132/255,255/255,0.15) : Qt.rgba(1,1,1,0.06)
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
                                text: "No wallpapers found"; font.pixelSize: 12; color: root.textSecondary
                                visible: !userModel.count }

                            Grid {
                                id: ugrid; width: parent.width; columns: 3; spacing: 8; visible: userModel.count > 0
                                Repeater {
                                    model: userModel
                                    Rectangle {
                                        id: tile
                                        required property string name
                                        required property string imgPath
                                        required property string slug
                                        width: (ugrid.width - 16) / 3; height: width * 0.6
                                        radius: 8; clip: true; color: "#0d1b2a"
                                        border.width: 1; border.color: tma.containsMouse ? root.accent : root.cardBorder
                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        Image {
                                            anchors.fill: parent; source: tile.imgPath
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true; smooth: true; mipmap: true; cache: false
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
                                                let thumbSrc = root.userDir + "/" + tile.slug + "/thumb.jpg"
                                                root.applyWallpaper(root.userDir+"/"+tile.slug+"/wallpaper.jpg", tile.name, thumbSrc)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cardBorder }
                    LibSect { Layout.fillWidth: true; label: "Landscapes" }
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
            implicitHeight: nf.implicitHeight
            Text { id: nf; anchors.horizontalCenter: parent.horizontalCenter; text: "No wallpapers found"; font.pixelSize: 12; color: root.textSecondary }
        }
    }
}
