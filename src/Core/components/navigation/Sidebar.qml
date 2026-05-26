import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".." as Components

Item {
    id: root

    required property var   model
    required property int   selectedIndex
    property var translationMessages: ({})
    signal selectIndex(int index)
    signal openUserProfile()

    property string userName:   ""
    property string avatarPath: ""
    property int avatarVersion: 0
    property bool   isSudo:     false
    property int expansionVersion: 0

    function translatedLabel(item) {
        const key = item.labelKey !== undefined ? item.labelKey : ""
        if (key.length > 0 && root.translationMessages && root.translationMessages[key])
            return root.translationMessages[key]
        return item.label || ""
    }

    function isSectionExpanded(sectionKey, version) {
        version
        if (!sectionKey || sectionKey.length === 0)
            return true
        for (let i = 0; i < root.model.count; i++) {
            const item = root.model.get(i)
            if (item.kind === "section" && item.sectionKey === sectionKey)
                return !!item.expanded
        }
        return true
    }

    function toggleSection(index) {
        const item = root.model.get(index)
        if (!item || item.kind !== "section")
            return
        root.model.setProperty(index, "expanded", !item.expanded)
        root.expansionVersion += 1
    }

    Component.onCompleted: {
        userName   = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
        avatarPath = "/var/lib/AccountsService/icons/" + userName
        checkSudoProc.running = true
    }

    Process {
        id: checkSudoProc
        command: ["bash", "-c", "groups " + root.userName + " | grep -q 'wheel\\|sudo'"]
        onExited: (exitCode) => root.isSudo = (exitCode === 0)
    }

    Components.SidebarFrame {
        anchors.fill: parent
        backgroundColor: Components.Theme.themeMode === 1
            ? (Components.Theme.shellStyle === 0 ? Qt.rgba(1, 1, 1, 0.18)
                : Components.Theme.shellStyle === 2 ? Qt.rgba(0.98, 0.99, 1, 0.28)
                : Qt.rgba(0.985, 0.987, 0.994, 0.96))
            : Qt.rgba(1, 1, 1, 0.05)
        washColor: Components.Theme.themeMode === 1
            ? (Components.Theme.shellStyle === 0 ? Qt.rgba(1, 1, 1, 0.04)
                : Components.Theme.shellStyle === 2 ? Qt.rgba(1, 1, 1, 0.10)
                : Qt.rgba(1, 1, 1, 0.04))
            : Qt.rgba(1, 1, 1, 0.015)
        borderColor: Components.Theme.themeMode === 1
            ? (Components.Theme.shellStyle === 0 ? Qt.rgba(0, 0, 0, 0.08)
                : Components.Theme.shellStyle === 2 ? Qt.rgba(0, 0, 0, 0.10)
                : Qt.rgba(0, 0, 0, 0.09))
            : Qt.rgba(1, 1, 1, 0.08)
        contentTopPadding: 16
        contentBottomPadding: 16
        contentSpacing: 2

        // ── Profile header ────────────────────────────────────────────────
        Item {
            width: parent.width - 32
            x: 16
            height: 64

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openUserProfile()
            }

            RowLayout {
                anchors.fill: parent
                spacing: 12

                // Avatar
                Item {
                    Layout.alignment: Qt.AlignVCenter
                    width: 48
                    height: 48

                    Components.AvatarImage {
                        anchors.fill: parent
                        imagePath: root.avatarPath
                        imageVersion: root.avatarVersion
                        fallbackText: root.userName.length > 0
                            ? root.userName[0].toUpperCase()
                            : "?"
                        fallbackFontFamily: Components.Theme.fontFamily
                        fallbackFontPixelSize: Components.Theme.fontSizeAvatar
                        fallbackFontWeight: Components.Theme.fontWeightMedium
                        sourceScale: 4
                        maskMargin: 1
                        borderWidth: 1
                        borderColor: Qt.rgba(1, 1, 1, 0.18)
                    }
                }

                // Nome e Sudo badge
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.userName
                        font.family: Components.Theme.fontFamily
                        font.pixelSize: Components.Theme.fontSizeLarge
                        font.weight: Components.Theme.fontWeightMedium
                        color: Components.Theme.textPrimary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "sudo"
                        font.family: Components.Theme.fontFamily
                        font.pixelSize: Components.Theme.fontSizeTiny
                        font.weight: Components.Theme.fontWeightNormal
                        color: Components.Theme.textTertiary
                        visible: root.isSudo
                    }
                }
            }
        }

        // Divisor
        Rectangle {
            width: parent.width - 32
            x: 16
            height: 1
            color: Components.Theme.cardBorder
        }

        Item { width: 1; height: 4 }

        // ── Nav items ─────────────────────────────────────────────────────
        Repeater {
            model: root.model
            delegate: Item {
                id: navDelegate

                readonly property string itemKind: model.kind !== undefined && model.kind.length > 0 ? model.kind : "page"
                readonly property int targetPageIndex: model.pageIndex !== undefined ? model.pageIndex : index
                readonly property bool childOpen: itemKind !== "child"
                    || root.isSectionExpanded(model.parentSection !== undefined ? model.parentSection : "", root.expansionVersion)
                    || root.selectedIndex === targetPageIndex

                width: parent.width
                height: itemKind === "spacer" ? 12 : (childOpen ? (itemKind === "section" ? 32 : (itemKind === "child" ? 36 : 40)) : 0)
                visible: height > 0
                clip: true

                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Components.NavItem {
                    anchors.fill: parent
                    visible:    navDelegate.itemKind !== "section" && navDelegate.itemKind !== "spacer"
                    label:      root.translatedLabel(model)
                    sym:        model.sym !== undefined ? model.sym : ""
                    iconSource: model.iconSource !== undefined ? model.iconSource : ""
                    iconKey:    model.iconKey !== undefined ? model.iconKey : ""
                    leftInset:  navDelegate.itemKind === "child" ? 24 : 0
                    compact:    navDelegate.itemKind === "child"
                    selected:   root.selectedIndex === navDelegate.targetPageIndex
                    onClicked:  root.selectIndex(navDelegate.targetPageIndex)
                }

                Rectangle {
                    visible: navDelegate.itemKind === "section"
                    anchors {
                        fill: parent
                        leftMargin: 8
                        rightMargin: 8
                        topMargin: 3
                        bottomMargin: 3
                    }
                    radius: 8
                    color: sectionMouse.containsMouse
                        ? (Components.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.045))
                        : "transparent"
                    border.width: sectionMouse.containsMouse ? 1 : 0
                    border.color: Components.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(1, 1, 1, 0.05)

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 10
                        }
                        spacing: 8

                        Text {
                            text: root.isSectionExpanded(model.sectionKey !== undefined ? model.sectionKey : "", root.expansionVersion) ? "⌄" : "›"
                            color: Components.Theme.textTertiary
                            font.family: Components.Theme.fontFamily
                            font.pixelSize: Components.Theme.fontSizeSmall
                            horizontalAlignment: Text.AlignHCenter
                            Layout.preferredWidth: 14
                        }

                        Text {
                            text: root.translatedLabel(model)
                            color: Components.Theme.textSecondary
                            font.family: Components.Theme.fontFamily
                            font.pixelSize: Components.Theme.fontSizeSmall
                            font.weight: Components.Theme.fontWeightDemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: sectionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSection(index)
                    }
                }
            }
        }

        Item { width: 1; height: 8 }
    }
}
