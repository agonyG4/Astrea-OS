import QtQuick 2.15

QtObject {
    id: selection

    property QtObject app
    property string selectedFile: ""
    property var selectedFiles: []
    property int lastSelectedIndex: -1

    function isSelected(name) {
        if (!name) return false
        if (selectedFiles.indexOf(name) !== -1) return true
        return name === selectedFile
    }

    function clearSelection() {
        selectedFile = ""
        selectedFiles = []
        lastSelectedIndex = -1
    }

    function handleSelection(name, index, ctrlMode, shiftMode, preserveCurrentSelection) {
        if (preserveCurrentSelection && isSelected(name))
            return

        if (!ctrlMode && !shiftMode) {
            selectedFile = name
            selectedFiles = [name]
            lastSelectedIndex = index
            return
        }

        if (ctrlMode) {
            var arr = selectedFiles.slice()
            var existingIdx = arr.indexOf(name)
            if (existingIdx !== -1) {
                arr.splice(existingIdx, 1)
                selectedFiles = arr
                if (selectedFile === name)
                    selectedFile = arr.length > 0 ? arr[arr.length - 1] : ""
            } else {
                arr.push(name)
                selectedFiles = arr
                selectedFile = name
            }
            lastSelectedIndex = index
            return
        }

        if (shiftMode && lastSelectedIndex !== -1 && index !== -1) {
            var min = Math.min(lastSelectedIndex, index)
            var max = Math.max(lastSelectedIndex, index)
            var range = []
            for (var i = min; i <= max; ++i) {
                if (i < app.fileModel.count)
                    range.push(app.fileModel.get(i).fileName)
            }
            selectedFiles = range
            selectedFile = name
        }
    }

    function selectAll() {
        var all = []
        for (var i = 0; i < app.fileModel.count; i++)
            all.push(app.fileModel.get(i).fileName)
        selectedFiles = all
        if (all.length > 0)
            selectedFile = all[all.length - 1]
    }

    function selectByName(name) {
        if (!name)
            return
        selectedFile = name
        selectedFiles = [name]
        lastSelectedIndex = -1
        for (var i = 0; i < app.fileModel.count; i++) {
            if (app.fileModel.get(i).fileName === name) {
                lastSelectedIndex = i
                return
            }
        }
    }
}
