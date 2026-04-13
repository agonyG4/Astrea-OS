import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../"

PanelWindow {
    id: notificationWindow
    
    // Posiciona no canto superior direito, abaixo da sua Bar de 48px
    anchors { top: true; right: true }
    anchors.topMargin: 56 // 48 da bar + 8 de respiro
    anchors.rightMargin: 12
    
    width: 350
    height: Math.min(contentCol.implicitHeight + 20, 600)
    color: "transparent"

    WlrLayershell.namespace: "notifications"
    WlrLayershell.layer:     WlrLayer.Overlay
    
    // O segredo do Liquid Glass: Um ColumnLayout que cresce conforme chegam notificações
    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: notificationModel // Aqui é onde os dados vão entrar

            delegate: Rectangle {
                id: card
                Layout.fillWidth: true
                implicitHeight: 80
                radius: 12
                
                // Estética Liquid Glass (igual ao Spotlight)
                color: Theme.background
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 12

                    // Ícone da Notificação ou App
                    Rectangle {
                        width: 40; height: 40
                        radius: 8; color: Theme.surface
                        
                        Text {
                            anchors.centerIn: parent
                            text: model.appIcon || "🔔"
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeLarge }
                        }
                    }

                    // Conteúdo Texto
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Text {
                            text: model.summary || "Notificação"
                            color: Theme.textActive
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeTitle; weight: Font.Bold }
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.body || "Conteúdo da mensagem..."
                            color: Theme.textSecondary
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody }
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // Botão Fechar (X)
                    MouseArea {
                        width: 20; height: 20
                        Layout.alignment: Qt.AlignTop
                        onClicked: notificationModel.remove(index)

                        Text {
                            text: "✕"
                            color: Theme.textActive; opacity: 0.5
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody }
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }

    // Modelo temporário para você testar o visual agora mesmo
    ListModel {
        id: notificationModel
        ListElement { summary: "Astrea AI"; body: "Sistema de notificações pronto, Vitor!"; appIcon: "🤖" }
        ListElement { summary: "Spotify"; body: "Tocando: Liquid Glass (Phonk Remix)"; appIcon: "🎵" }
    }
}