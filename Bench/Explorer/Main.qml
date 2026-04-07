import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components/layout" as LayoutComponents
import "components/views" as ViewComponents
import "components/common" as CommonComponents

ApplicationWindow {
    id: window
    visible: true
    width: 1100; height: 680
    minimumWidth: 700; minimumHeight: 450
    title: "Finder"
    color: Theme.bg

    Component.onCompleted: {
        Qt.application.name = "Explorer"
        Qt.application.organization = "agony"
        Qt.application.domain = "local"
        AppState.navigateTo(AppState.currentPath || "/home/agony")
        AppState.scheduleHomeThumbnailWarmup()
    }

    onClosing: function(close) {
        Qt.quit()
    }

    Shortcut {
        sequences: ["Ctrl++", "Ctrl+="]
        onActivated: AppState.increaseZoom()
    }

    Shortcut {
        sequences: ["Ctrl+-", "Ctrl+_"]
        onActivated: AppState.decreaseZoom()
    }

    Shortcut {
        sequence: "Ctrl+0"
        onActivated: AppState.resetZoom()
    }

    Shortcut {
        sequence: "Space"
        onActivated: AppState.openQuickLook()
    }

    Shortcut {
        sequence: "Ctrl+C"
        onActivated: AppState.copySelected()
    }

    Shortcut {
        sequence: "Ctrl+X"
        onActivated: AppState.cutSelected()
    }

    Shortcut {
        sequence: "Ctrl+V"
        onActivated: AppState.pasteFiles()
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: AppState.createTab()
    }

    Shortcut {
        sequence: "Ctrl+W"
        onActivated: AppState.closeTab(AppState.activeTabIndex)
    }

    Shortcut {
        sequence: "Ctrl+A"
        onActivated: AppState.selectAll()
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: AppState.startSearch()
    }

    Shortcut {
        sequence: "Delete"
        onActivated: AppState.deleteSelected()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar (Full Height) ────────────────────────────
        LayoutComponents.Sidebar { Layout.fillHeight: true; Layout.preferredWidth: 224 }

        // ── Main Content Area ────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Tab Bar ──────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 34
                color: Theme.bg
                visible: AppState.tabs.length > 1
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    spacing: 2
                    
                    Repeater {
                        model: AppState.tabs
                        
                        Rectangle {
                            width: Math.min(200, (parent.width - 40) / AppState.tabs.length)
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 6
                            color: index === AppState.activeTabIndex ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: AppState.switchTab(index)
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    visible: parent.containsMouse && index !== AppState.activeTabIndex
                                }
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 6
                                
                                Text {
                                    text: {
                                        var p = modelData.path;
                                        if (p === "/home/agony") return "Pasta pessoal";
                                        return p.split("/").pop() || "Raiz";
                                    }
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: index === AppState.activeTabIndex ? Theme.text : Theme.textTer
                                    font.pixelSize: 12
                                }
                                
                                Text {
                                    text: "×"
                                    color: Theme.textTer
                                    font.pixelSize: 14
                                    visible: AppState.tabs.length > 1
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: AppState.closeTab(index)
                                    }
                                }
                            }
                        }
                    }
                    
                    CommonComponents.NavButton {
                        text: "+"
                        width: 28; height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: AppState.createTab()
                    }
                }
                
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            }

            // ── Toolbar ──────────────────────────────────────
            LayoutComponents.Toolbar { Layout.fillWidth: true }


            // ── View Area (Files) ────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Área principal
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bg

                    Loader {
                        anchors.fill: parent
                        sourceComponent: AppState.viewMode === "list" ? listComp : iconComp
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Pasta vazia"; color: Theme.textTer; font.pixelSize: 15
                        visible: !AppState.loadingDir && AppState.fileModel.count === 0 && AppState.loadError === ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Carregando..."; color: Theme.textTer; font.pixelSize: 15
                        visible: AppState.loadingDir
                    }

                    Text {
                        anchors.centerIn: parent
                        text: AppState.loadError; color: "#ff8b8b"; font.pixelSize: 15
                        visible: AppState.loadError !== ""
                    }
                }

                // Painel de preview
                LayoutComponents.PreviewPanel {
                    width: AppState.showPreview ? 220 : 0
                    Layout.fillHeight: true
                    visible: AppState.showPreview
                }
            }

            // ── Status bar ───────────────────────────────────
            LayoutComponents.StatusBar { Layout.fillWidth: true }
        }
    }

    Component { id: listComp; ViewComponents.FileListView {} }
    Component { id: iconComp; ViewComponents.FileIconView {} }


    Popup {
        id: pasteConflictPopup
        anchors.centerIn: parent
        width: 420
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.NoAutoClose
        visible: AppState.pasteConflictVisible

        background: Rectangle {
            radius: 14
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Column {
            spacing: 12
            padding: 16

            Text {
                text: "Arquivos com o mesmo nome"
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.text
                font.pixelSize: 12
                text: AppState.pasteConflictItems.length === 1
                      ? "Ja existe um item com esse nome no destino. O que voce quer fazer?"
                      : "Ja existem " + AppState.pasteConflictItems.length + " itens com o mesmo nome no destino. O que voce quer fazer com todos eles?"
            }

            TextField {
                visible: AppState.pasteConflictItems.length === 1
                width: parent.width
                text: AppState.pendingPasteRename
                color: Theme.text
                placeholderText: "Novo nome"
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: Theme.bg
                    border.color: parent.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                }
                onTextChanged: AppState.pendingPasteRename = text
                onAccepted: AppState.renamePasteConflict(text)
            }

            Rectangle {
                width: parent.width
                height: Math.min(conflictColumn.implicitHeight + 12, 140)
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: width
                    contentHeight: conflictColumn.implicitHeight
                    clip: true

                    Column {
                        id: conflictColumn
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: AppState.pasteConflictItems

                            Text {
                                width: conflictColumn.width
                                text: modelData
                                color: Theme.textTer
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }

            Row {
                spacing: 8

                DialogButton {
                    label: "Cancelar"
                    onClicked: AppState.cancelPasteConflict()
                }

                DialogButton {
                    label: "Ignorar"
                    onClicked: AppState.resolvePasteConflict("skip")
                }

                DialogButton {
                    visible: AppState.pasteConflictItems.length === 1
                    label: "Renomear"
                    onClicked: AppState.renamePasteConflict(AppState.pendingPasteRename)
                }

                DialogButton {
                    label: "Manter ambos"
                    emphasized: true
                    onClicked: AppState.resolvePasteConflict("keep-both")
                }

                DialogButton {
                    label: "Sobrescrever"
                    danger: true
                    onClicked: AppState.resolvePasteConflict("overwrite")
                }
            }
        }
    }

    component DialogButton: Rectangle {
        property string label: ""
        property bool emphasized: false
        property bool danger: false
        signal clicked()

        width: 92
        height: 34
        radius: 8
        color: danger ? Qt.rgba(0.8, 0.24, 0.24, buttonMouse.containsMouse ? 0.35 : 0.22)
                      : emphasized ? (buttonMouse.containsMouse ? Theme.accentSoft : Theme.accentLight)
                      : (buttonMouse.containsMouse ? Theme.hover : Theme.toolbar)

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: Theme.text
            font.pixelSize: 12
            font.weight: parent.emphasized || parent.danger ? Font.Medium : Font.Normal
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Popup {
        id: networkConnectPopup
        anchors.centerIn: parent
        width: 440
        modal: true
        focus: true
        padding: 0
        closePolicy: AppState.networkConnecting ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
        visible: AppState.networkConnectVisible

        onVisibleChanged: {
            if (!visible && AppState.networkConnectVisible && !AppState.networkConnecting)
                AppState.hideNetworkConnectDialog()
        }

        background: Rectangle {
            radius: 14
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Column {
            spacing: 12
            padding: 16

            Text {
                text: "Conectar ao servidor"
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.textSec
                font.pixelSize: 12
                text: "Use um endereço como smb://servidor/compartilhamento ou sftp://usuario@host/caminho."
            }

            TextField {
                id: networkAddressField
                width: parent.width
                text: AppState.networkAddress
                enabled: !AppState.networkConnecting
                color: Theme.text
                placeholderText: "smb://servidor/compartilhamento"
                placeholderTextColor: Theme.textTer
                selectByMouse: true
                font.pixelSize: 13
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: networkAddressField.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                }
                onTextChanged: AppState.networkAddress = text
                onAccepted: AppState.connectToNetwork()
                Component.onCompleted: {
                    if (AppState.networkAddress === "")
                        AppState.networkAddress = "smb://"
                }
            }

            Text {
                visible: AppState.networkError !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#ff9a9a"
                font.pixelSize: 12
                text: AppState.networkError
            }

            Row {
                spacing: 8

                Rectangle {
                    width: 96
                    height: 32
                    radius: 8
                    color: cancelNetworkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancelar"
                        color: Theme.text
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelNetworkMouse
                        anchors.fill: parent
                        enabled: !AppState.networkConnecting
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: AppState.hideNetworkConnectDialog()
                    }
                }

                Rectangle {
                    width: 96
                    height: 32
                    radius: 8
                    color: connectNetworkMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: AppState.networkConnecting ? "Conectando..." : "Conectar"
                        color: "white"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: connectNetworkMouse
                        anchors.fill: parent
                        enabled: !AppState.networkConnecting
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: AppState.connectToNetwork()
                    }
                }
            }
        }
    }
}
