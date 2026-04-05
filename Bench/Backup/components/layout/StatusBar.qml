import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "../.."

Rectangle {
    height: 26
    color: Theme.statusBar

    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }

    Row {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 16

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textTer; font.pixelSize: 11
            text: AppState.fileModel.count +
                  (AppState.fileModel.count === 1 ? " item" : " itens")
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textTer; font.pixelSize: 11
            text: {
                if (AppState.selectedFiles.length > 1) return AppState.selectedFiles.length + " itens selecionados"
                if (AppState.selectedFiles.length === 1) return "\"" + AppState.selectedFiles[0] + "\" selecionado"
                return ""
            }
        }
    }
}
