import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "../.."

Rectangle {
    width: 208
    color: Theme.sidebar

    Rectangle {
        anchors.fill: parent
        opacity: 0.95
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.sidebarAlt }
            GradientStop { position: 0.2; color: Theme.sidebar }
            GradientStop { position: 1.0; color: Qt.darker(Theme.sidebar, 1.08) }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true

        Column {
            width: parent.width
            topPadding: 18
            bottomPadding: 18
            spacing: 4

            // ── Header: título + botão de busca ──────────────
            Item {
                width: parent.width - 32
                x: 16
                height: 32

                Text {
                    anchors.centerIn: parent
                    text: "Finder"
                    color: Theme.text
                    font { pixelSize: 24; weight: Font.DemiBold; letterSpacing: -0.4 }
                }

                Rectangle {
                    id: searchBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 28
                    height: 28
                    radius: 6
                    color: searchHover.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.08)
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: 80 } }

                    IconImage {
                        name: "system-search"
                        width: 15; height: 15
                        sourceSize: Qt.size(15, 15)
                        anchors.centerIn: parent
                        opacity: 0.6
                        visible: !AppState.isPortalDialog
                    }

                    Image {
                        source: AppState.portalIconSource("system-search", 16)
                        width: 15
                        height: 15
                        anchors.centerIn: parent
                        opacity: 0.75
                        visible: AppState.isPortalDialog
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }

                    MouseArea {
                        id: searchHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.startSearch()
                    }
                }
            }

            Item { width: 1; height: 14 }

            // ── Pessoal ──────────────────────────────────────
            SidebarSection { label: "PESSOAL" }
            SidebarItem { icon: "inode-directory";      label: "Pasta Pessoal"; path: "/home/agony" }
            SidebarItem { icon: "document-open-recent"; label: "Recentes";      path: "/home/agony" }

            // ── Favoritos ────────────────────────────────────
            SidebarSection { label: "FAVORITOS" }
            Repeater {
                model: [
                    { label: "Desktop",    icon: "user-desktop",     path: "/home/agony/Área de trabalho" },
                    { label: "Documentos", icon: "folder-documents", path: "/home/agony/Documentos" },
                    { label: "Downloads",  icon: "folder-downloads", path: "/home/agony/Downloads" },
                    { label: "Imagens",    icon: "folder-pictures",  path: "/home/agony/Imagens" },
                    { label: "Músicas",    icon: "folder-music",     path: "/home/agony/Músicas" },
                    { label: "Vídeos",     icon: "folder-videos",    path: "/home/agony/Vídeos" },
                    { label: "Público",    icon: "folder-publicshare", path: "/home/agony/Público" },
                    { label: "Modelos",    icon: "folder-templates", path: "/home/agony/Modelos" },
                ]
                SidebarItem { icon: modelData.icon; label: modelData.label; path: modelData.path }
            }

            // ── Dispositivos ─────────────────────────────────
            SidebarSection { label: "DISPOSITIVOS" }
            SidebarItem { icon: "drive-harddisk";    label: "Macintosh HD"; path: "/"          }
            SidebarItem { icon: "network-workgroup"; label: "Rede";         path: "/run/media" }

            // ── Outro ────────────────────────────────────────
            SidebarSection { label: "OUTRO" }
            SidebarItem {
                icon: "user-trash"; label: "Lixeira"
                path: "/home/agony/.local/share/Trash/files"
            }
        }
    }

    // Divisor direito
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Qt.lighter(Theme.border, 1.12)
        opacity: 0.8
    }

    // ── Sub-componentes internos ──────────────────────────────
    component SidebarSection: Text {
        property alias label: self.text
        id: self
        width: parent ? parent.width : 208
        height: 30
        leftPadding: 16
        topPadding: 10
        verticalAlignment: Text.AlignVCenter
        color: Theme.textTer
        font { pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
    }

    component SidebarItem: Rectangle {
        id: sbItem
        property string icon
        property string label
        property string path
        readonly property bool active: AppState.currentPath === path

        width: parent ? parent.width - 18 : 190
        height: 34
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        radius: 12
        color: active
            ? Qt.rgba(0.22, 0.5, 0.95, 0.24)
            : hover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

        border.width: active ? 1 : 0
        border.color: active ? Qt.rgba(0.6, 0.8, 1, 0.22) : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 12
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 10

            Rectangle {
                width: 22
                height: 22
                radius: 7
                color: active ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    name: sbItem.icon
                    width: 14; height: 14
                    sourceSize: Qt.size(14, 14)
                    anchors.centerIn: parent
                    visible: !AppState.isPortalDialog
                }

                Image {
                    source: AppState.portalIconSource(sbItem.icon, 16)
                    width: 14
                    height: 14
                    anchors.centerIn: parent
                    visible: AppState.isPortalDialog
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }
            }

            Text {
                text: sbItem.label
                color: sbItem.active ? Theme.text : Qt.lighter(Theme.text, 1.02)
                font { pixelSize: 13; weight: sbItem.active ? Font.DemiBold : Font.Medium }
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: sbItem.active ? parent.width - 59 : parent.width - 46
            }

            Rectangle {
                width: 5
                height: 5
                radius: 2.5
                color: Theme.accent
                visible: sbItem.active
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: hover; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: AppState.navigateTo(sbItem.path)
        }
    }
}
