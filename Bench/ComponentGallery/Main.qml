import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "AstreaComponents" as Astrea

FloatingWindow {
    id: window

    title: "Astrea Components"
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(980, 620)
    visible: true
    color: "transparent"

    property int selectedSection: 0
    property string activityText: "Ready"
    property string focusComponent: ""
    readonly property color panelOverlay: Astrea.Theme.themeMode === 1
        ? Qt.rgba(1, 1, 1, 0.10)
        : Qt.rgba(1, 1, 1, 0.035)

    function sectionLabel(index) {
        if (index < 0 || index >= sectionModel.count)
            return "Sidebar"
        return sectionModel.get(index).label
    }

    function selectSection(index) {
        selectedSection = index
        focusComponent = ""
        activityText = "Showing " + sectionLabel(index)
    }

    function sectionForComponent(name) {
        if (name === "SidebarFrame" || name === "NavItem" || name === "SidebarCollapseButton")
            return 0
        if (name === "Button" || name === "ButtonCapsule" || name === "DualButton" || name === "FloatingButton")
            return 1
        if (name === "FormCard" || name === "SettingRow" || name === "SearchField" || name === "SelectButton" || name === "ToggleSwitch" || name === "IconListRow")
            return 2
        if (name === "ContextMenu" || name === "ContextMenuAction" || name === "ContextMenuDivider")
            return 3
        if (name === "StatusDot" || name === "DnsStatusCard" || name === "DnsPresetChip" || name === "ProgressCard")
            return 4
        if (name === "AvatarImage" || name === "TextLabel" || name === "DisplayLabel" || name === "Divider")
            return 5
        return 0
    }

    function previewComponent(name) {
        selectedSection = sectionForComponent(name)
        focusComponent = name
        activityText = "Previewing " + name
    }

    function previewSource(name) {
        if (name === "Button")
            return buttonPreview
        if (name === "ButtonCapsule")
            return capsulePreview
        if (name === "DualButton")
            return dualButtonPreview
        if (name === "FloatingButton")
            return floatingButtonPreview
        if (name === "SidebarFrame")
            return sidebarFramePreview
        if (name === "NavItem")
            return navItemPreview
        if (name === "SidebarCollapseButton")
            return collapseButtonPreview
        if (name === "FormCard")
            return formCardPreview
        if (name === "SettingRow")
            return settingRowPreview
        if (name === "SearchField")
            return searchFieldPreview
        if (name === "SelectButton")
            return selectButtonPreview
        if (name === "ToggleSwitch")
            return toggleSwitchPreview
        if (name === "IconListRow")
            return iconListRowPreview
        if (name === "ContextMenu")
            return contextMenuPreview
        if (name === "ContextMenuAction")
            return contextMenuActionPreview
        if (name === "ContextMenuDivider")
            return contextMenuDividerPreview
        if (name === "StatusDot")
            return statusDotPreview
        if (name === "DnsStatusCard")
            return dnsStatusPreview
        if (name === "DnsPresetChip")
            return dnsChipPreview
        if (name === "ProgressCard")
            return progressCardPreview
        if (name === "AvatarImage")
            return avatarPreview
        if (name === "TextLabel")
            return textLabelPreview
        if (name === "DisplayLabel")
            return displayLabelPreview
        if (name === "Divider")
            return dividerPreview
        return emptyPreview
    }

    function note(message) {
        activityText = message
    }

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    ListModel {
        id: sectionModel
        ListElement { label: "Sidebar"; detail: "Navigation surfaces"; icon: "S" }
        ListElement { label: "Buttons"; detail: "Actions and segmented controls"; icon: "B" }
        ListElement { label: "Form"; detail: "Rows, toggles and selects"; icon: "F" }
        ListElement { label: "Menus"; detail: "Context menus and actions"; icon: "M" }
        ListElement { label: "Feedback"; detail: "Status, chips and progress"; icon: "!" }
        ListElement { label: "Typography"; detail: "Labels, dividers and avatar"; icon: "T" }
    }

    component SampleCard: Rectangle {
        id: card

        property string title: ""
        property string detail: ""
        property real maxContentWidth: 900
        default property alias content: slot.data

        Layout.fillWidth: true
        Layout.maximumWidth: maxContentWidth
        implicitHeight: Math.max(130, content.implicitHeight + 34)
        radius: Astrea.Theme.cardRadius
        color: Astrea.Theme.cardBg
        border.width: 1
        border.color: Astrea.Theme.cardBorder

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: Astrea.Theme.textPrimary
                    font.family: Astrea.Theme.fontFamily
                    font.pixelSize: Astrea.Theme.fontSizeLarge
                    font.weight: Astrea.Theme.fontWeightDemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: card.detail !== ""
                    text: card.detail
                    color: Astrea.Theme.textSecondary
                    font.family: Astrea.Theme.fontFamily
                    font.pixelSize: Astrea.Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: slot
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
            }
        }
    }

    component SectionPage: Flickable {
        id: page

        default property alias content: column.data

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: column.implicitHeight + 8

        ColumnLayout {
            id: column
            width: Math.min(page.width, 940)
            x: Math.max(0, (page.width - width) / 2)
            spacing: 16
        }
    }

    Component {
        id: emptyPreview
        Text {
            text: "No component selected"
            color: Astrea.Theme.textSecondary
            font.family: Astrea.Theme.fontFamily
            font.pixelSize: Astrea.Theme.fontSizeNormal
        }
    }

    Component {
        id: buttonPreview
        Flow {
            spacing: 12
            Astrea.Button { text: "Default"; onClicked: window.note("Default button clicked") }
            Astrea.Button { text: "Primary"; primary: true; onClicked: window.note("Primary button clicked") }
            Astrea.Button { text: "Danger"; danger: true; onClicked: window.note("Danger button clicked") }
            Astrea.Button { text: "Flat"; flat: true; onClicked: window.note("Flat button clicked") }
            Astrea.Button { text: "Icon"; iconText: "+"; onClicked: window.note("Icon button clicked") }
            Astrea.Button { text: "Disabled"; enabled: false }
        }
    }

    Component {
        id: capsulePreview
        Flow {
            spacing: 12
            Astrea.ButtonCapsule { text: "Capsule"; onClicked: window.note("Capsule clicked") }
            Astrea.ButtonCapsule { text: "Primary"; primary: true; onClicked: window.note("Primary capsule clicked") }
            Astrea.ButtonCapsule { text: "Danger"; danger: true; onClicked: window.note("Danger capsule clicked") }
        }
    }

    Component {
        id: dualButtonPreview
        Astrea.DualButton {
            leftText: "Light"
            rightText: "Dark"
            selectedIndex: 0
            onClicked: index => {
                selectedIndex = index
                window.note((index === 0 ? "Light" : "Dark") + " selected")
            }
        }
    }

    Component {
        id: floatingButtonPreview
        Flow {
            spacing: 14
            Astrea.FloatingButton { text: "Floating"; onClicked: window.note("Floating clicked") }
            Astrea.FloatingButton { text: ""; iconText: "↻"; onClicked: window.note("Icon floating clicked") }
            Astrea.FloatingButton { text: "Primary"; primary: true; onClicked: window.note("Primary floating clicked") }
        }
    }

    Component {
        id: sidebarFramePreview
        Astrea.SidebarFrame {
            width: 340
            height: 230
            topMargin: 0
            bottomMargin: 0
            leftMargin: 0
            rightMargin: 0
            contentTopPadding: 18
            contentBottomPadding: 18
            contentSpacing: 8

            Text {
                width: parent.width - 32
                x: 16
                text: "SidebarFrame"
                color: Astrea.Theme.textPrimary
                font.family: Astrea.Theme.fontFamily
                font.pixelSize: Astrea.Theme.fontSizeLarge
                font.weight: Astrea.Theme.fontWeightDemiBold
            }
            Astrea.NavItem { width: parent.width; label: "Selected item"; iconKey: "wallpaper"; selected: true }
            Astrea.NavItem { width: parent.width; label: "Idle item"; iconKey: "display"; selected: false }
        }
    }

    Component {
        id: navItemPreview
        Column {
            width: 340
            spacing: 8
            Astrea.NavItem { width: parent.width; label: "Selected NavItem"; iconKey: "wallpaper"; selected: true }
            Astrea.NavItem { width: parent.width; label: "Idle NavItem"; iconKey: "apps"; selected: false }
        }
    }

    Component {
        id: collapseButtonPreview
        Row {
            spacing: 16
            Astrea.SidebarCollapseButton { controlSize: 36; collapsed: false; onClicked: window.note("Expanded icon clicked") }
            Astrea.SidebarCollapseButton { controlSize: 36; collapsed: true; onClicked: window.note("Collapsed icon clicked") }
        }
    }

    Component {
        id: formCardPreview
        Astrea.FormCard {
            width: 520
            margins: 0
            spacing: 0
            Astrea.SettingRow {
                label: "FormCard row"
                sublabel: "Default content slot with a live control."
                isLast: true
                Astrea.ToggleSwitch { checked: true }
            }
        }
    }

    Component {
        id: settingRowPreview
        Astrea.SettingRow {
            width: 560
            label: "SettingRow"
            sublabel: "Label, sublabel, hover behavior and a trailing control."
            isLast: true
            Astrea.Button { text: "Action"; onClicked: window.note("SettingRow action clicked") }
        }
    }

    Component {
        id: searchFieldPreview
        Column {
            width: 460
            spacing: 12

            Astrea.SearchField {
                width: parent.width
                placeholderText: "Search components"
                selectAllOnFocus: true
                onTextEdited: text => window.note("SearchField: " + (text || "empty"))
                onAccepted: text => window.note("Search accepted: " + text)
                onCleared: window.note("Search cleared")
            }

            Astrea.SearchField {
                width: parent.width
                text: "Weather"
                placeholderText: "With clear action"
                onTextEdited: text => window.note("SearchField changed: " + text)
            }
        }
    }

    Component {
        id: selectButtonPreview
        Astrea.SelectButton {
            width: 190
            label: "Normal"
            options: ["Slow", "Normal", "Fast"]
            selectedIndex: 1
            onSelected: index => {
                selectedIndex = index
                label = options[index]
                window.note("SelectButton: " + options[index])
            }
        }
    }

    Component {
        id: toggleSwitchPreview
        Astrea.ToggleSwitch {
            checked: true
            onToggled: targetChecked => {
                checked = targetChecked
                window.note("ToggleSwitch " + (targetChecked ? "on" : "off"))
            }
        }
    }

    Component {
        id: iconListRowPreview
        Rectangle {
            width: 520
            height: 108
            radius: Astrea.Theme.cardRadius
            color: Astrea.Theme.cardBg
            border.width: 1
            border.color: Astrea.Theme.cardBorder
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Astrea.IconListRow { label: "IconListRow"; sublabel: "Interactive row"; iconText: "I"; onClicked: window.note("IconListRow clicked") }
                Astrea.IconListRow { label: "With chevron"; sublabel: "Secondary value"; iconText: "C"; showChevron: true; isLast: true; onClicked: window.note("Chevron row clicked") }
            }
        }
    }

    Component {
        id: contextMenuPreview
        Item {
            width: 420
            height: 220

            Rectangle {
                anchors.fill: parent
                radius: Astrea.Theme.cardRadius
                color: window.panelOverlay
                border.width: 1
                border.color: Astrea.Theme.cardBorder

                Text {
                    anchors {
                        left: parent.left
                        top: parent.top
                        margins: 16
                    }
                    text: "Context target"
                    color: Astrea.Theme.textSecondary
                    font.family: Astrea.Theme.fontFamily
                    font.pixelSize: Astrea.Theme.fontSizeNormal
                }

                Astrea.Button {
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                        margins: 16
                    }
                    text: "Open menu"
                    primary: true
                    onClicked: contextMenu.openAt(x + width + 12, y)
                }
            }

            Astrea.ContextMenu {
                id: contextMenu
                menuWidth: 210
                panelColor: Astrea.Theme.popupBg
                borderColor: Astrea.Theme.cardBorder
                cardRadius: Astrea.Theme.cardRadius

                Astrea.ContextMenuAction {
                    label: "Open"
                    hoverColor: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.18)
                    textColor: Astrea.Theme.textPrimary
                    onTriggered: {
                        contextMenu.closeMenu()
                        window.note("ContextMenuAction: Open")
                    }
                }
                Astrea.ContextMenuAction {
                    label: "Move to..."
                    hasSubmenu: true
                    hoverColor: Qt.rgba(1, 1, 1, 0.08)
                    textColor: Astrea.Theme.textPrimary
                    onTriggered: window.note("Submenu action")
                }
                Astrea.ContextMenuDivider {
                    lineColor: Astrea.Theme.cardBorder
                }
                Astrea.ContextMenuAction {
                    label: "Delete"
                    destructive: true
                    hoverColor: Qt.rgba(1, 0.27, 0.23, 0.16)
                    textColor: Astrea.Theme.errorColor
                    onTriggered: {
                        contextMenu.closeMenu()
                        window.note("ContextMenuAction: Delete")
                    }
                }
            }

            Component.onCompleted: Qt.callLater(() => contextMenu.openAt(188, 52))
        }
    }

    Component {
        id: contextMenuActionPreview
        Rectangle {
            width: 260
            height: 110
            radius: Astrea.Theme.cardRadius
            color: Astrea.Theme.popupBg
            border.width: 1
            border.color: Astrea.Theme.cardBorder

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                spacing: 0

                Astrea.ContextMenuAction {
                    label: "Normal action"
                    hoverColor: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.18)
                    textColor: Astrea.Theme.textPrimary
                    onTriggered: window.note("ContextMenuAction clicked")
                }
                Astrea.ContextMenuAction {
                    label: "Submenu action"
                    hasSubmenu: true
                    hoverColor: Qt.rgba(1, 1, 1, 0.08)
                    textColor: Astrea.Theme.textPrimary
                    onTriggered: window.note("ContextMenuAction submenu clicked")
                }
                Astrea.ContextMenuAction {
                    label: "Disabled action"
                    actionEnabled: false
                    textColor: Astrea.Theme.textPrimary
                    disabledTextColor: Astrea.Theme.textTertiary
                }
            }
        }
    }

    Component {
        id: contextMenuDividerPreview
        Rectangle {
            width: 260
            height: 72
            radius: Astrea.Theme.cardRadius
            color: Astrea.Theme.popupBg
            border.width: 1
            border.color: Astrea.Theme.cardBorder

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 0

                Astrea.ContextMenuAction {
                    label: "Before divider"
                    textColor: Astrea.Theme.textPrimary
                    hoverColor: Qt.rgba(1, 1, 1, 0.08)
                }
                Astrea.ContextMenuDivider {
                    lineColor: Astrea.Theme.cardBorder
                }
                Astrea.ContextMenuAction {
                    label: "After divider"
                    textColor: Astrea.Theme.textPrimary
                    hoverColor: Qt.rgba(1, 1, 1, 0.08)
                }
            }
        }
    }

    Component {
        id: statusDotPreview
        Row {
            spacing: 16
            Astrea.StatusDot { active: true; pulse: true }
            Astrea.StatusDot { active: false; pulse: false }
        }
    }

    Component {
        id: dnsStatusPreview
        Astrea.DnsStatusCard {
            width: 420
            providerLabel: "Automatic DNS"
            detail: "Resolved by the current network profile."
            badgeColor: Astrea.Theme.accent
            isAuto: true
        }
    }

    Component {
        id: dnsChipPreview
        Flow {
            spacing: 12
            Astrea.DnsPresetChip { label: "Cloudflare"; selected: true; chipColor: Astrea.Theme.accent; onClicked: window.note("Cloudflare clicked") }
            Astrea.DnsPresetChip { label: "Google"; chipColor: "#34a853"; onClicked: window.note("Google clicked") }
            Astrea.DnsPresetChip { label: "Quad9"; chipColor: "#ffcc00"; onClicked: window.note("Quad9 clicked") }
        }
    }

    Component {
        id: progressCardPreview
        Item {
            width: 340
            height: 92

            Astrea.ProgressCard {
                anchors.left: parent.left
                anchors.top: parent.top
                title: "ProgressCard"
                detail: "Copying components"
                destination: "Preview"
                progress: 0.64
                completedItems: 14
                totalItems: 22
                panelColor: Astrea.Theme.cardBg
                borderColor: Astrea.Theme.cardBorder
                primaryTextColor: Astrea.Theme.textPrimary
                secondaryTextColor: Astrea.Theme.textSecondary
                trackColor: Qt.rgba(1, 1, 1, 0.12)
                fillColor: Astrea.Theme.accent
            }
        }
    }

    Component {
        id: avatarPreview
        Row {
            spacing: 16
            Astrea.AvatarImage {
                width: 64
                height: 64
                fallbackText: "A"
                borderWidth: 1
                borderColor: Astrea.Theme.cardBorder
            }
            Astrea.AvatarImage {
                width: 48
                height: 48
                fallbackText: "OS"
                fallbackColor: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.25)
            }
        }
    }

    Component {
        id: textLabelPreview
        Astrea.TextLabel {
            text: "TextLabel preview"
            textColor: Astrea.Theme.textSecondary
            font.pixelSize: 18
        }
    }

    Component {
        id: displayLabelPreview
        Astrea.DisplayLabel {
            text: "DisplayLabel"
            font.pixelSize: 34
            font.weight: Astrea.Theme.fontWeightDemiBold
        }
    }

    Component {
        id: dividerPreview
        Column {
            width: 460
            spacing: 12
            Astrea.TextLabel { text: "Above divider"; textColor: Astrea.Theme.textSecondary }
            Astrea.Divider { width: parent.width }
            Astrea.TextLabel { text: "Below divider"; textColor: Astrea.Theme.textTertiary }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Astrea.Theme.windowBackground
        border.width: 1
        border.color: Astrea.Theme.windowBorder
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.58)
            shadowBlur: 0.95
            shadowVerticalOffset: 10
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Astrea.Theme.windowWash
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 22

            Astrea.SidebarFrame {
                Layout.preferredWidth: 254
                Layout.fillHeight: true
                topMargin: 0
                bottomMargin: 0
                leftMargin: 0
                rightMargin: 0
                cornerRadius: 22
                contentTopPadding: 18
                contentBottomPadding: 18
                contentSpacing: 10

                Column {
                    width: parent.width - 34
                    x: 17
                    spacing: 4

                    Text {
                        width: parent.width
                        text: "Astrea Components"
                        color: Astrea.Theme.textPrimary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeTitle
                        font.weight: Astrea.Theme.fontWeightDemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: sectionModel.count + " sections"
                        color: Astrea.Theme.textSecondary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeSmall
                    }
                }

                Rectangle {
                    width: parent.width - 34
                    x: 17
                    height: 1
                    color: Astrea.Theme.cardBorder
                }

                ListView {
                    id: sectionList
                    width: parent.width
                    height: contentHeight
                    interactive: false
                    model: sectionModel
                    currentIndex: window.selectedSection

                    delegate: Item {
                        id: sectionDelegate

                        required property int index
                        required property string label
                        required property string detail
                        required property string icon

                        width: sectionList.width
                        height: 54

                        Rectangle {
                            anchors {
                                fill: parent
                                leftMargin: 8
                                rightMargin: 8
                                topMargin: 4
                                bottomMargin: 4
                            }
                            radius: 12
                            color: sectionDelegate.index === window.selectedSection
                                ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.16)
                                : (sectionHover.hovered ? window.panelOverlay : "transparent")
                            border.width: sectionDelegate.index === window.selectedSection ? 1 : 0
                            border.color: Astrea.Theme.accent

                            Behavior on color { ColorAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 18
                                rightMargin: 16
                            }
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                radius: 9
                                color: sectionDelegate.index === window.selectedSection
                                    ? Astrea.Theme.accent
                                    : Astrea.Theme.cardBg
                                border.width: 1
                                border.color: sectionDelegate.index === window.selectedSection
                                    ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.60)
                                    : Astrea.Theme.cardBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: sectionDelegate.icon
                                    color: sectionDelegate.index === window.selectedSection
                                        ? Astrea.Theme.accentForeground
                                        : Astrea.Theme.textSecondary
                                    font.family: Astrea.Theme.fontFamily
                                    font.pixelSize: Astrea.Theme.fontSizeSmall
                                    font.weight: Astrea.Theme.fontWeightBold
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: sectionDelegate.label
                                    color: Astrea.Theme.textPrimary
                                    font.family: Astrea.Theme.fontFamily
                                    font.pixelSize: Astrea.Theme.fontSizeNormal
                                    font.weight: Astrea.Theme.fontWeightMedium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: sectionDelegate.detail
                                    color: Astrea.Theme.textSecondary
                                    font.family: Astrea.Theme.fontFamily
                                    font.pixelSize: Astrea.Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        HoverHandler { id: sectionHover }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.selectSection(sectionDelegate.index)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: sectionModel.get(window.selectedSection).label
                            color: Astrea.Theme.textPrimary
                            font.family: Astrea.Theme.fontFamily
                            font.pixelSize: 30
                            font.weight: Astrea.Theme.fontWeightDemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.activityText + " - live preview from ~/.local/share/Astrea"
                            color: Astrea.Theme.textSecondary
                            font.family: Astrea.Theme.fontFamily
                            font.pixelSize: Astrea.Theme.fontSizeNormal
                            elide: Text.ElideRight
                        }
                    }

                    Astrea.FloatingButton {
                        text: ""
                        iconText: "↻"
                        controlHeight: 40
                        onClicked: window.note("Preview refreshed")
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: window.selectedSection

                    SectionPage {
                        SampleCard {
                            visible: window.focusComponent !== ""
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            title: window.focusComponent
                            detail: "Focused live preview from the selected component."

                            Loader {
                                width: parent.width
                                sourceComponent: window.previewSource(window.focusComponent)
                            }
                        }

                        SampleCard {
                            title: "SidebarFrame + NavItem"
                            detail: "The same navigation stack used by Settings-like apps."

                            Astrea.SidebarFrame {
                                width: 320
                                height: 260
                                topMargin: 0
                                bottomMargin: 0
                                leftMargin: 0
                                rightMargin: 0
                                contentTopPadding: 18
                                contentBottomPadding: 18
                                contentSpacing: 8

                                Text {
                                    width: parent.width - 32
                                    x: 16
                                    text: "Navigation"
                                    color: Astrea.Theme.textPrimary
                                    font.family: Astrea.Theme.fontFamily
                                    font.pixelSize: Astrea.Theme.fontSizeLarge
                                    font.weight: Astrea.Theme.fontWeightDemiBold
                                }

                                Astrea.NavItem { width: parent.width; label: "Wallpapers"; iconKey: "wallpaper"; selected: true }
                                Astrea.NavItem { width: parent.width; label: "Display"; iconKey: "display"; selected: false }
                                Astrea.NavItem { width: parent.width; label: "Apps"; iconKey: "apps"; selected: false }
                            }
                        }

                        SampleCard {
                            title: "SidebarCollapseButton"
                            detail: "Tiny standalone component for collapsible app sidebars."

                            RowLayout {
                                width: parent.width
                                spacing: 20

                                Astrea.SidebarCollapseButton {
                                    controlSize: 34
                                    collapsed: false
                                }

                                Astrea.SidebarCollapseButton {
                                    controlSize: 34
                                    collapsed: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "The glyph stays icon-only and can be wired to any sidebar width animation."
                                    color: Astrea.Theme.textSecondary
                                    font.family: Astrea.Theme.fontFamily
                                    font.pixelSize: Astrea.Theme.fontSizeNormal
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    SectionPage {
                        SampleCard {
                            visible: window.focusComponent !== ""
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            title: window.focusComponent
                            detail: "Focused live preview from the selected component."

                            Loader {
                                width: parent.width
                                sourceComponent: window.previewSource(window.focusComponent)
                            }
                        }

                        SampleCard {
                            title: "Button"
                            detail: "Default, primary, danger, flat and disabled states."

                            Flow {
                                width: parent.width
                                spacing: 12

                                Astrea.Button { text: "Default"; onClicked: window.note("Default button clicked") }
                                Astrea.Button { text: "Primary"; primary: true; onClicked: window.note("Primary button clicked") }
                                Astrea.Button { text: "Danger"; danger: true; onClicked: window.note("Danger button clicked") }
                                Astrea.Button { text: "Flat"; flat: true; onClicked: window.note("Flat button clicked") }
                                Astrea.Button { text: "Disabled"; enabled: false }
                                Astrea.Button { text: "Icon"; iconText: "+"; onClicked: window.note("Icon button clicked") }
                            }
                        }

                        SampleCard {
                            title: "Specialized Controls"
                            detail: "ButtonCapsule for pill actions, DualButton for segmented choices, FloatingButton for compact toolbar actions."

                            Flow {
                                width: parent.width
                                spacing: 14

                                Astrea.ButtonCapsule { text: "Capsule"; onClicked: window.note("Capsule clicked") }
                                Astrea.ButtonCapsule { text: "Install"; primary: true; onClicked: window.note("Install capsule clicked") }
                                Astrea.DualButton {
                                    leftText: "Light"
                                    rightText: "Dark"
                                    selectedIndex: 1
                                    onClicked: index => {
                                        selectedIndex = index
                                        window.note((index === 0 ? "Light" : "Dark") + " segment selected")
                                    }
                                }
                                Astrea.FloatingButton { text: ""; iconText: "↻"; onClicked: window.note("Refresh action clicked") }
                                Astrea.FloatingButton { text: ""; iconText: "⌘"; onClicked: window.note("Command action clicked") }
                            }
                        }
                    }

                    SectionPage {
                        SampleCard {
                            visible: window.focusComponent !== ""
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            title: window.focusComponent
                            detail: "Focused live preview from the selected component."

                            Loader {
                                width: parent.width
                                sourceComponent: window.previewSource(window.focusComponent)
                            }
                        }

                        SampleCard {
                            title: "FormCard + SettingRow"
                            detail: "Settings-style rows with inline controls."

                            Astrea.FormCard {
                                width: parent.width
                                margins: 0
                                spacing: 0

                                Astrea.SettingRow {
                                    label: "Use frosted surfaces"
                                    sublabel: "ToggleSwitch in the row control slot."
                                    Astrea.ToggleSwitch {
                                        checked: true
                                        onToggled: targetChecked => {
                                            checked = targetChecked
                                            window.note("Frosted surfaces " + (targetChecked ? "enabled" : "disabled"))
                                        }
                                    }
                                }

                                Astrea.SettingRow {
                                    label: "Animation speed"
                                    sublabel: "SelectButton opens with the component popup."
                                    Astrea.SelectButton {
                                        width: 160
                                        label: "Normal"
                                        options: ["Slow", "Normal", "Fast"]
                                        selectedIndex: 1
                                        onSelected: index => {
                                            selectedIndex = index
                                            label = options[index]
                                            window.note("Animation speed: " + options[index])
                                        }
                                    }
                                }

                                Astrea.SettingRow {
                                    label: "Danger row"
                                    sublabel: "Button as a trailing row action."
                                    isLast: true
                                    Astrea.Button { text: "Reset"; danger: true; onClicked: window.note("Reset clicked") }
                                }
                            }
                        }

                        SampleCard {
                            title: "SearchField"
                            detail: "Reusable text search control with real TextField focus, clear action, Enter and Escape behavior."

                            Astrea.SearchField {
                                width: Math.min(parent.width, 560)
                                placeholderText: "Search current view"
                                selectAllOnFocus: true
                                onTextEdited: text => window.note("SearchField: " + (text || "empty"))
                                onAccepted: text => window.note("Search accepted: " + text)
                                onCleared: window.note("Search cleared")
                            }
                        }

                        SampleCard {
                            title: "IconListRow"
                            detail: "Compact list rows for menus, detail panels and inspectors."

                            Rectangle {
                                width: parent.width
                                height: 160
                                radius: Astrea.Theme.cardRadius
                                color: Astrea.Theme.cardBg
                                border.width: 1
                                border.color: Astrea.Theme.cardBorder

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Astrea.IconListRow { label: "Network"; sublabel: "Connected"; iconText: "N"; onClicked: window.note("Network row clicked") }
                                    Astrea.IconListRow { label: "Bluetooth"; sublabel: "Idle"; iconText: "B"; onClicked: window.note("Bluetooth row clicked") }
                                    Astrea.IconListRow { label: "Storage"; sublabel: "Healthy"; iconText: "S"; isLast: true; showChevron: true; onClicked: window.note("Storage row clicked") }
                                }
                            }
                        }
                    }

                    SectionPage {
                        SampleCard {
                            visible: window.focusComponent !== ""
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            title: window.focusComponent
                            detail: "Focused live preview from the selected component."

                            Loader {
                                width: parent.width
                                sourceComponent: window.previewSource(window.focusComponent)
                            }
                        }

                        SampleCard {
                            title: "ContextMenu"
                            detail: "Anchored overlay menu with edge-aware positioning and backdrop close."

                            Item {
                                width: Math.min(parent.width, 620)
                                height: 240

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Astrea.Theme.cardRadius
                                    color: window.panelOverlay
                                    border.width: 1
                                    border.color: Astrea.Theme.cardBorder

                                    Text {
                                        anchors {
                                            left: parent.left
                                            top: parent.top
                                            margins: 18
                                        }
                                        text: "Right-click style target"
                                        color: Astrea.Theme.textSecondary
                                        font.family: Astrea.Theme.fontFamily
                                        font.pixelSize: Astrea.Theme.fontSizeNormal
                                    }

                                    Astrea.Button {
                                        anchors {
                                            left: parent.left
                                            bottom: parent.bottom
                                            margins: 18
                                        }
                                        text: "Open menu"
                                        primary: true
                                        onClicked: demoMenu.openAt(x + width + 14, y)
                                    }
                                }

                                Astrea.ContextMenu {
                                    id: demoMenu
                                    menuWidth: 220
                                    panelColor: Astrea.Theme.popupBg
                                    borderColor: Astrea.Theme.cardBorder
                                    cardRadius: Astrea.Theme.cardRadius

                                    Astrea.ContextMenuAction {
                                        label: "Open"
                                        hoverColor: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.18)
                                        textColor: Astrea.Theme.textPrimary
                                        onTriggered: {
                                            demoMenu.closeMenu()
                                            window.note("ContextMenuAction: Open")
                                        }
                                    }
                                    Astrea.ContextMenuAction {
                                        label: "Move to..."
                                        hasSubmenu: true
                                        hoverColor: Qt.rgba(1, 1, 1, 0.08)
                                        textColor: Astrea.Theme.textPrimary
                                        onTriggered: window.note("ContextMenuAction submenu")
                                    }
                                    Astrea.ContextMenuDivider {
                                        lineColor: Astrea.Theme.cardBorder
                                    }
                                    Astrea.ContextMenuAction {
                                        label: "Delete"
                                        destructive: true
                                        hoverColor: Qt.rgba(1, 0.27, 0.23, 0.16)
                                        textColor: Astrea.Theme.errorColor
                                        onTriggered: {
                                            demoMenu.closeMenu()
                                            window.note("ContextMenuAction: Delete")
                                        }
                                    }

                                    Component.onCompleted: Qt.callLater(() => demoMenu.openAt(220, 56))
                                }
                            }
                        }

                        SampleCard {
                            title: "ContextMenuAction + ContextMenuDivider"
                            detail: "Menu rows support hover, disabled states, submenu chevrons and destructive actions."

                            Rectangle {
                                width: 280
                                height: 160
                                radius: Astrea.Theme.cardRadius
                                color: Astrea.Theme.popupBg
                                border.width: 1
                                border.color: Astrea.Theme.cardBorder

                                Column {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        margins: 8
                                    }
                                    spacing: 0

                                    Astrea.ContextMenuAction {
                                        label: "Rename"
                                        hoverColor: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.18)
                                        textColor: Astrea.Theme.textPrimary
                                        onTriggered: window.note("Rename clicked")
                                    }
                                    Astrea.ContextMenuAction {
                                        label: "Share"
                                        hasSubmenu: true
                                        hoverColor: Qt.rgba(1, 1, 1, 0.08)
                                        textColor: Astrea.Theme.textPrimary
                                        onTriggered: window.note("Share clicked")
                                    }
                                    Astrea.ContextMenuAction {
                                        label: "Disabled"
                                        actionEnabled: false
                                        textColor: Astrea.Theme.textPrimary
                                        disabledTextColor: Astrea.Theme.textTertiary
                                    }
                                    Astrea.ContextMenuDivider {
                                        lineColor: Astrea.Theme.cardBorder
                                    }
                                    Astrea.ContextMenuAction {
                                        label: "Delete"
                                        destructive: true
                                        hoverColor: Qt.rgba(1, 0.27, 0.23, 0.16)
                                        textColor: Astrea.Theme.errorColor
                                        onTriggered: window.note("Delete clicked")
                                    }
                                }
                            }
                        }
                    }

                    SectionPage {
                        SampleCard {
                            visible: window.focusComponent !== ""
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            title: window.focusComponent
                            detail: "Focused live preview from the selected component."

                            Loader {
                                width: parent.width
                                sourceComponent: window.previewSource(window.focusComponent)
                            }
                        }

                        SampleCard {
                            title: "StatusDot + DnsPresetChip"
                            detail: "Small state indicators and selectable chips."

                            Flow {
                                width: parent.width
                                spacing: 12

                                Rectangle {
                                    width: 120
                                    height: 38
                                    radius: 12
                                    color: window.panelOverlay
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 10
                                        Astrea.StatusDot { active: true; pulse: true; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "Online"; color: Astrea.Theme.textPrimary; font.family: Astrea.Theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }

                                Astrea.DnsPresetChip { label: "Cloudflare"; selected: true; chipColor: Astrea.Theme.accent; onClicked: window.note("Cloudflare chip clicked") }
                                Astrea.DnsPresetChip { label: "Google"; chipColor: "#34a853"; onClicked: window.note("Google chip clicked") }
                                Astrea.DnsPresetChip { label: "Quad9"; chipColor: "#ffcc00"; onClicked: window.note("Quad9 chip clicked") }
                            }
                        }

                        SampleCard {
                            title: "DnsStatusCard + ProgressCard"
                            detail: "Feedback cards for network state and background work."

                            Flow {
                                width: parent.width
                                spacing: 16

                                Rectangle {
                                    width: 390
                                    height: dnsPreview.implicitHeight + 20
                                    radius: 14
                                    color: window.panelOverlay
                                    border.width: 1
                                    border.color: Astrea.Theme.cardBorder

                                    Astrea.DnsStatusCard {
                                        id: dnsPreview
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            top: parent.top
                                            margins: 10
                                        }
                                        providerLabel: "Automatic DNS"
                                        detail: "Resolved by the current network profile."
                                        badgeColor: Astrea.Theme.accent
                                        isAuto: true
                                    }
                                }

                                Rectangle {
                                    width: 360
                                    height: 112
                                    radius: 14
                                    color: window.panelOverlay
                                    border.width: 1
                                    border.color: Astrea.Theme.cardBorder

                                    Astrea.ProgressCard {
                                        anchors {
                                            left: parent.left
                                            top: parent.top
                                            margins: 10
                                        }
                                        title: "Copying assets"
                                        detail: "Core/components"
                                        destination: "Bench/ComponentGallery"
                                        progress: 0.64
                                        completedItems: 14
                                        totalItems: 22
                                        panelColor: Astrea.Theme.cardBg
                                        borderColor: Astrea.Theme.cardBorder
                                        primaryTextColor: Astrea.Theme.textPrimary
                                        secondaryTextColor: Astrea.Theme.textSecondary
                                        trackColor: Qt.rgba(1, 1, 1, 0.12)
                                        fillColor: Astrea.Theme.accent
                                    }
                                }
                            }
                        }
                    }

                    SectionPage {
                        SampleCard {
                            visible: window.focusComponent !== ""
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            title: window.focusComponent
                            detail: "Focused live preview from the selected component."

                            Loader {
                                width: parent.width
                                sourceComponent: window.previewSource(window.focusComponent)
                            }
                        }

                        SampleCard {
                            title: "Typography"
                            detail: "TextLabel and DisplayLabel inherit Astrea font rendering and theme colors."

                            ColumnLayout {
                                width: parent.width
                                spacing: 10

                                Astrea.DisplayLabel {
                                    text: "DisplayLabel"
                                    font.pixelSize: 34
                                    font.weight: Astrea.Theme.fontWeightDemiBold
                                }

                                Astrea.TextLabel {
                                    Layout.fillWidth: true
                                    text: "TextLabel keeps the same rendering behavior and color transitions as Astrea UI surfaces."
                                    textColor: Astrea.Theme.textSecondary
                                    wrapMode: Text.WordWrap
                                }

                                Astrea.Divider { Layout.fillWidth: true }

                                Astrea.TextLabel {
                                    text: "Divider separates dense panels without adding visual noise."
                                    textColor: Astrea.Theme.textTertiary
                                }
                            }
                        }

                        SampleCard {
                            title: "AvatarImage"
                            detail: "Fallback initials, circular mask and themed border."

                            RowLayout {
                                width: parent.width
                                spacing: 18

                                Astrea.AvatarImage {
                                    Layout.preferredWidth: 64
                                    Layout.preferredHeight: 64
                                    fallbackText: "A"
                                    borderWidth: 1
                                    borderColor: Astrea.Theme.cardBorder
                                }

                                Astrea.AvatarImage {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    fallbackText: "OS"
                                    fallbackColor: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.25)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Use this when a user, app, or object needs a resilient circular identity mark."
                                    color: Astrea.Theme.textSecondary
                                    font.family: Astrea.Theme.fontFamily
                                    font.pixelSize: Astrea.Theme.fontSizeNormal
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}
