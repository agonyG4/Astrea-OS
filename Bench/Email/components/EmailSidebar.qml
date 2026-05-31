import QtQuick
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Astrea.SidebarFrame {
    id: sidebar

    property bool collapsed: false
    property string statusText: ""
    property string selectedFolder: "Inbox"
    property bool settingsOpen: false
    property int inboxUnread: 0
    property int draftsCount: 0
    signal composeRequested()
    signal folderRequested(string folder)
    signal collapseRequested(bool collapsed)
    signal settingsRequested()

    topMargin: 0
    bottomMargin: 0
    leftMargin: 0
    rightMargin: 0
    cornerRadius: 18
    contentTopPadding: Astrea.Theme.spacingMedium
    contentBottomPadding: Astrea.Theme.spacingLarge
    contentSpacing: Astrea.Theme.spacingTiny

    Item {
        width: parent.width
        height: 36

        Astrea.SidebarCollapseButton {
            anchors {
                right: parent.right
                rightMargin: sidebar.collapsed ? 13 : 14
                verticalCenter: parent.verticalCenter
            }
            collapsed: sidebar.collapsed
            controlSize: 30
            onClicked: sidebar.collapseRequested(!sidebar.collapsed)
        }
    }

    Column {
        width: parent.width - 28
        x: 14
        spacing: 2
        visible: !sidebar.collapsed
        opacity: sidebar.collapsed ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }

        Text {
            width: parent.width
            text: "Email"
            color: Astrea.Theme.textPrimary
            font.family: Astrea.Theme.fontFamily
            font.pixelSize: Astrea.Theme.fontSizeLarge
            font.weight: Astrea.Theme.fontWeightDemiBold
            elide: Text.ElideRight
        }

        Row {
            spacing: 7

            Astrea.StatusDot {
                anchors.verticalCenter: parent.verticalCenter
                active: true
            }

            Text {
                width: parent.parent.width - 20
                text: sidebar.statusText
                color: Astrea.Theme.textSecondary
                font.family: Astrea.Theme.fontFamily
                font.pixelSize: Astrea.Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        width: parent.width - 28
        x: 14
        height: 1
        color: Astrea.Theme.cardBorder
        visible: !sidebar.collapsed
    }

    Astrea.Button {
        width: parent.width - 16
        height: 36
        x: 8
        text: sidebar.collapsed ? "" : "Compose"
        iconText: "\uf304"
        iconFontFamily: "JetBrainsMono Nerd Font"
        primary: true
        controlHeight: 36
        onClicked: sidebar.composeRequested()
    }

    Item { width: 1; height: 5 }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "Inbox" + (sidebar.inboxUnread > 0 ? "  " + sidebar.inboxUnread : "")
        sym: "\uf01c"
        selected: !sidebar.settingsOpen && sidebar.selectedFolder === "Inbox"
        onClicked: sidebar.folderRequested("Inbox")
    }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "Starred"
        sym: "\uf005"
        selected: !sidebar.settingsOpen && sidebar.selectedFolder === "Starred"
        onClicked: sidebar.folderRequested("Starred")
    }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "Sent"
        sym: "\uf1d8"
        selected: !sidebar.settingsOpen && sidebar.selectedFolder === "Sent"
        onClicked: sidebar.folderRequested("Sent")
    }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "Drafts" + (sidebar.draftsCount > 0 ? "  " + sidebar.draftsCount : "")
        sym: "\uf15c"
        selected: !sidebar.settingsOpen && sidebar.selectedFolder === "Drafts"
        onClicked: sidebar.folderRequested("Drafts")
    }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "Archive"
        sym: "\uf187"
        selected: !sidebar.settingsOpen && sidebar.selectedFolder === "Archive"
        onClicked: sidebar.folderRequested("Archive")
    }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "All Mail"
        sym: "\uf0e0"
        selected: !sidebar.settingsOpen && sidebar.selectedFolder === "All"
        onClicked: sidebar.folderRequested("All")
    }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "Trash"
        sym: "\uf1f8"
        selected: !sidebar.settingsOpen && sidebar.selectedFolder === "Trash"
        onClicked: sidebar.folderRequested("Trash")
    }

    Item {
        width: 1
        height: Math.max(16, sidebar.height - (sidebar.collapsed ? 420 : 500))
    }

    Rectangle {
        width: parent.width - 28
        x: 14
        height: 1
        color: Astrea.Theme.cardBorder
        opacity: 0.8
        visible: !sidebar.collapsed
    }

    Astrea.NavItem {
        width: parent.width
        label: sidebar.collapsed ? "" : "Settings"
        sym: "\uf013"
        selected: sidebar.settingsOpen
        onClicked: sidebar.settingsRequested()
    }
}
