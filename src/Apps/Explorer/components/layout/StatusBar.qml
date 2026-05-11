import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "../.."

Rectangle {
    height: 26
    color: Theme.bg
    readonly property string clipboardText: {
        if (AppState.clipboardFiles.length === 0)
            return ""
        var verb = AppState.clipboardMode === "cut" ? "recortado" : "copiado"
        return AppState.clipboardFiles.length + (AppState.clipboardFiles.length === 1 ? " item " : " itens ") + verb
    }
    readonly property string operationText: {
        if (AppState.fileOperationRunning)
            return AppState.fileOperationStatus || (AppState.fileOperationMode === "move" ? "Movendo..." : "Copiando...")
        if (AppState.archiveExtractionRunning)
            return AppState.archiveExtractionStatus
        return ""
    }

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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textTer
            font.pixelSize: 11
            text: clipboardText
            visible: clipboardText !== ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: AppState.fileOperationError !== "" ? "#ff8b8b" : Theme.textTer
            font.pixelSize: 11
            text: operationText
            visible: operationText !== ""
        }
    }
}
