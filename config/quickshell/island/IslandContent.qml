import QtQuick
import Qt5Compat.GraphicalEffects
import "../bar" as Bar

Rectangle {
    id: islandContent

    // ── Estado derivado ───────────────────────────────────────────
    readonly property bool isGamemodeNotify:       island.showGamemodeNotify
    readonly property bool isMouseOver:            mouseArea.hovered
    readonly property bool isDragHover:            hungry.containsDrag
    readonly property bool isSwallowingDrag:       isDragHover && !isGamemodeNotify
    readonly property bool suppressMusicInSmallDrag: isSwallowingDrag && island.hasMusic
    readonly property real flipScale:              Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))
    readonly property bool isNotch:                island.islandConfig.style === "Notch"
    readonly property bool showTabBar:             island.hasDroppedImages && !isGamemodeNotify
    readonly property bool filesTabActive:         island.activeTab === "files"
    readonly property real tabBarHeight:           32

    // ── Dimensões ─────────────────────────────────────────────────
    width: {
        if (isGamemodeNotify)  return isNotch ? 210 : 100
        if (isSwallowingDrag)  return isNotch ? 260 : 230
        if (!island.hasMusic)
            return isNotch ? 210 : 120
        if (island.isExpanded)
            return isNotch ? 380 : 360
        if (!island.showCompactMusic)
            return isNotch ? 210 : 120
        return isNotch ? 210 : 180
    }
    height: {
        if (isGamemodeNotify)  return 100
        if (isSwallowingDrag)  return isNotch ? 58 : 64
        if (!island.hasMusic)
            return isNotch ? 32 : 34
        if (island.isExpanded)
            return 160 + (showTabBar ? tabBarHeight : 0)
        if (!island.showCompactMusic)
            return isNotch ? 32 : 34
        return isNotch ? 32 : 34
    }

    property real currentRadius: {
        if (isGamemodeNotify)  return 32
        if (island.isExpanded) return (isNotch && !island.hasMusic) ? 17 : 32
        return 17
    }

    radius:            currentRadius
    color:             "transparent"
    clip:              true
    transformOrigin:   Item.Top
    scale:             pulseScale
    anchors {
        horizontalCenter: parent.horizontalCenter
        top:              parent.top
        topMargin:        isNotch ? 0 : 8
    }

    property real pulseScale: 1.0
    function triggerPulse() { islandPulse.start() }

    SequentialAnimation {
        id: islandPulse
        NumberAnimation { target: islandContent; property: "pulseScale"; to: 1.045; duration: 70;  easing.type: Easing.OutQuad }
        NumberAnimation { target: islandContent; property: "pulseScale"; to: 1.0;   duration: 480; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
    }

    Behavior on width         { NumberAnimation { duration: (island.isExpanded || isGamemodeNotify) ? flipAnim.containerExpandDuration  : flipAnim.containerCollapseDuration; easing.type: Easing.OutExpo } }
    Behavior on height        { NumberAnimation { duration: (island.isExpanded || isGamemodeNotify) ? flipAnim.containerExpandDuration  : flipAnim.containerCollapseDuration; easing.type: Easing.OutExpo } }
    Behavior on currentRadius { NumberAnimation { duration: flipAnim.radiusDuration; easing.type: Easing.OutExpo } }

    // ── Background ────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       parent.currentRadius
        color:        Bar.Theme.islandBackground

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height:  parent.radius
            color:   parent.color
            visible: islandContent.isNotch
        }
    }

    HoverHandler { id: mouseArea }

    // ── Compact: CAVA ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible:      opacity > 0
        opacity:      (!isGamemodeNotify && island.showCompactMusic && !isMouseOver && !suppressMusicInSmallDrag) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            spacing: 3
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }

            Repeater {
                model: 6
                Item {
                    width: 3; height: 20
                    Rectangle {
                        width:  3
                        height: Math.min(island.cavaMaxHeightCompact, Math.max(island.cavaMinHeight, island.cavaBars[index] / 100 * 18))
                        radius: 2
                        anchors.centerIn: parent
                        color:  island.dominantCol
                        Behavior on height { NumberAnimation { duration: 60;  easing.type: Easing.OutSine } }
                        Behavior on color  { ColorAnimation  { duration: 800 } }
                    }
                }
            }
        }
    }

    // ── Gamemode notify ───────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible:      opacity > 0
        opacity:      isGamemodeNotify ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text:             "🎮"
            font.family:       Bar.Theme.fontFamilyDisplay
            font.pixelSize:    48
            antialiasing:      true
            renderType:        Text.NativeRendering
            RotationAnimation on rotation {
                from: 0; to: 360; duration: 1500
                loops: Animation.Infinite; running: isGamemodeNotify
            }
        }
    }

    // ── Tab bar ───────────────────────────────────────────────────
    Item {
        id: tabBarItem
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height:  tabBarHeight
        visible: opacity > 0

        readonly property bool shouldShow: showTabBar && island.isExpanded
        opacity: shouldShow ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: tabBarItem.shouldShow ? 0 : -8
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }
        }

        Item {
            anchors.centerIn: parent
            width:  tabRow.implicitWidth + 8
            height: 24

            Rectangle {
                anchors.fill:  parent
                radius:        12
                color:         "#18ffffff"
                border.width:  1
                border.color:  "#08ffffff"
            }

            Rectangle {
                id:     tabIndicator
                width:  filesTabActive ? filesTab.width : homeTab.width
                height: 20
                radius: 10
                color:  "#28ffffff"
                x:      filesTabActive ? filesTab.x + 4 : homeTab.x + 4
                y:      2
                Behavior on x     { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }
            }

            Row {
                id:             tabRow
                anchors.centerIn: parent
                spacing:        2

                component TabItem: Item {
                    property string label
                    property bool   active
                    property string tabId

                    width:  tabLabel.implicitWidth + 24
                    height: 24

                    Text {
                        id:             tabLabel
                        anchors.centerIn: parent
                        text:           label
                        font.family:    Bar.Theme.fontFamilyText
                        font.pixelSize: 10
                        font.weight:    active ? Font.DemiBold : Font.Normal
                        color:          active ? Bar.Theme.textActive : Bar.Theme.textSecondary
                        antialiasing:   true
                        renderType:     Text.NativeRendering
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     island.activeTab = tabId
                    }
                }

                TabItem { id: homeTab;  label: "Home";  active: !filesTabActive; tabId: "home" }

                Item {
                    id:     filesTab
                    width:  filesLabel.implicitWidth + 24
                    height: 24

                    Rectangle {
                        visible: island.droppedImages.length > 0
                        anchors { right: parent.right; top: parent.top; rightMargin: 6; topMargin: 5 }
                        width: 6; height: 6; radius: 3; z: 5
                        color: island.dominantCol
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    Text {
                        id:             filesLabel
                        anchors.centerIn: parent
                        text:           "Files"
                        font.family:    Bar.Theme.fontFamilyText
                        font.pixelSize: 10
                        font.weight:    filesTabActive ? Font.DemiBold : Font.Normal
                        color:          filesTabActive ? Bar.Theme.textActive : Bar.Theme.textSecondary
                        antialiasing:   true
                        renderType:     Text.NativeRendering
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    island.activeTab = "files"
                    }
                }
            }
        }
    }

    // ── Home: MusicView ───────────────────────────────────────────
    MusicView {
        id: musicView
        anchors { fill: parent; topMargin: showTabBar ? tabBarHeight - 4 : 0 }
    }

    // ── Files: Gallery ────────────────────────────────────────────
    Item {
        id: filesView
        anchors { left: parent.left; right: parent.right; top: tabBarItem.bottom; bottom: parent.bottom; margins: 10; topMargin: 4 }

        readonly property bool shouldShow: filesTabActive && island.isExpanded && !isGamemodeNotify
        visible: opacity > 0
        opacity: shouldShow ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        transform: Translate {
            y: filesView.shouldShow ? 0 : 8
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }
        }

        Flickable {
            anchors.fill:   parent
            contentHeight:  fileGrid.height
            clip:           true
            interactive:    fileGrid.height > height

            Flow {
                id:         fileGrid
                width:      parent.width
                spacing:    8
                topPadding: 4

                Repeater {
                    model: island.droppedImages
                    delegate: Item {
                        id:     gridTile
                        width:  54; height: 54

                        readonly property string cat: procs.getFileCategory(modelData)
                        property bool removal:  false
                        property bool appeared: false

                        Timer {
                            interval: index * 35
                            running:  filesView.shouldShow && !appeared
                            onTriggered: {
                                appeared = true
                                Qt.callLater(() => gridTile.grabToImage(r => { gridTile.Drag.imageSource = r.url }, Qt.size(54, 54)))
                            }
                        }

                        opacity: appeared && !removal ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 250 } }

                        transform: Scale {
                            origin.x: 27; origin.y: 27
                            xScale: appeared && !removal ? 1 : 0
                            yScale: xScale
                            Behavior on xScale { NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] } }
                        }

                        Rectangle {
                            anchors.fill:  parent
                            radius:        12
                            color:         "#1c1c22"
                            clip:          true
                            border.width:  1
                            border.color:  gridHover.containsMouse ? "#55ffffff" : Qt.rgba(1, 1, 1, 0.1)

                            Image {
                                anchors.fill: parent
                                visible:      cat === "image"
                                source:       cat === "image" ? modelData : ""
                                fillMode:     Image.PreserveAspectCrop
                                asynchronous: true
                                cache:        false
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                visible: cat !== "image"
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: procs.getCategoryEmoji(cat)
                                    font.family: Bar.Theme.fontFamilyDisplay
                                    font.pixelSize: 22
                                    antialiasing: true
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: ("." + procs.getFileExtension(modelData)).toUpperCase()
                                    font.family: Bar.Theme.fontFamilyText
                                    font.pixelSize: 7
                                    font.weight: Font.Bold
                                    color: procs.getCategoryAccent(cat)
                                    antialiasing: true
                                    renderType: Text.NativeRendering
                                }
                            }

                            Rectangle {
                                visible: cat !== "image"
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height:  2.5
                                color:   procs.getCategoryAccent(cat)
                                opacity: 0.7
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius:  12
                                color:   "#20ffffff"
                                opacity: gridHover.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }
                        }

                        HoverHandler { id: gridHover }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: if (tapCount === 1) procs.openFile(modelData)
                        }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: { gridTile.removal = true; Qt.callLater(() => procs.removeDroppedFile(modelData)) }
                        }

                        DragHandler {
                            id:     gridDrag
                            target: null
                            property bool out: false
                            onActiveChanged: {
                                if (active)
                                    gridTile.grabToImage(r => { gridTile.Drag.imageSource = r.url }, Qt.size(54, 54))
                                if (!active && out) {
                                    gridTile.removal = true
                                    Qt.callLater(() => procs.removeDroppedFile(modelData))
                                }
                            }
                            onTranslationChanged: {
                                if (!active) return
                                var p = gridTile.mapToItem(islandContent, centroid.position.x, centroid.position.y)
                                out = p.x < 0 || p.y < 0 || p.x > islandContent.width || p.y > islandContent.height
                            }
                        }

                        Drag.active:   gridDrag.active
                        Drag.dragType: Drag.Automatic
                        Drag.mimeData: ({ "text/uri-list": modelData })
                        Drag.hotSpot:  Qt.point(27, 27)
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing:          8
            visible:          island.droppedImages.length === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "📂"
                font.family: Bar.Theme.fontFamilyDisplay
                font.pixelSize: 32
                antialiasing: true
                renderType: Text.NativeRendering
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Drop files anywhere"
                font.family: Bar.Theme.fontFamilyText
                font.pixelSize: 10
                font.weight: Font.Normal
                color: Bar.Theme.textSecondary
                opacity: 0.6
                antialiasing: true
                renderType: Text.NativeRendering
            }
        }

        Text {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: -2 }
            text:    "click to open • right-click to remove"
            font.family: Bar.Theme.fontFamilyText
            font.pixelSize: 8
            color:   "#44ffffff"
            antialiasing: true
            renderType: Text.NativeRendering
            visible: island.droppedImages.length > 0
        }
    }

    // ── Drag target ───────────────────────────────────────────────
    Hungry {
        id:    hungry
        anchors.fill:       parent
        isGamemodeNotify:   islandContent.isGamemodeNotify
        isMouseOver:        islandContent.isMouseOver
        hasDroppedImages:   island.hasDroppedImages
        hasMusic:           island.hasMusic
        compactDragActive:  islandContent.suppressMusicInSmallDrag
        droppedImages:      island.droppedImages
        currentRadius:      islandContent.currentRadius
        procs:              procs
    }

    // ── Floating album art ────────────────────────────────────────
    Item {
        id:      floatingArt
        visible: opacity > 0
        opacity: (island.hasMusic && !isGamemodeNotify && !suppressMusicInSmallDrag && !filesTabActive && (island.showCompactMusic || island.isExpanded)) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        readonly property bool artExpanded: island.isExpanded && island.hasMusic && !isGamemodeNotify

        Rectangle {
            id:      artClipMask
            anchors.fill: parent
            radius:  floatingArt.artExpanded ? 12 : floatingArt.width / 2
            visible: false
            Behavior on radius { NumberAnimation { duration: floatingArt.artExpanded ? flipAnim.artExpandDuration : flipAnim.artCollapseDuration; easing.type: Easing.OutExpo } }
        }

        Item {
            anchors.fill: parent
            transform: Scale {
                origin.x: floatingArt.width  / 2
                origin.y: floatingArt.height / 2
                xScale:   islandContent.flipScale
            }
            Image {
                anchors.fill: parent
                source:       island.artSource
                fillMode:     Image.PreserveAspectCrop
                smooth: true; mipmap: true; cache: false; asynchronous: true
                opacity: source === "" || status === Image.Loading ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                layer.enabled: true
                layer.effect:  OpacityMask { maskSource: artClipMask }
            }
        }

        states: [
            State {
                name: "expanded"; when: floatingArt.artExpanded
                PropertyChanges { target: floatingArt; x: 18; y: 18 + (showTabBar ? tabBarHeight - 4 : 0); width: 60; height: 60 }
            },
            State {
                name: "compact"; when: !floatingArt.artExpanded
                PropertyChanges { target: floatingArt; x: 8; y: 7; width: 20; height: 20 }
            }
        ]
        transitions: [
            Transition {
                from: "compact"; to: "expanded"
                NumberAnimation { properties: "x,y,width,height";    duration: flipAnim.artExpandDuration;   easing.type: Easing.OutExpo }
                NumberAnimation { target: artClipMask; property: "radius"; duration: flipAnim.artExpandDuration;   easing.type: Easing.OutExpo }
            },
            Transition {
                from: "expanded"; to: "compact"
                NumberAnimation { properties: "x,y,width,height";    duration: flipAnim.artCollapseDuration; easing.type: Easing.OutExpo }
                NumberAnimation { target: artClipMask; property: "radius"; duration: flipAnim.artCollapseDuration; easing.type: Easing.OutExpo }
            }
        ]
    }
}
