import QtQuick
import "../../../.."

Item {
    id: module

    property var control: null

    Row {
        anchors.fill: parent
        spacing: Theme.spacingMedium

        ConnectivityModule {
            width: (parent.width - parent.spacing) / 2
            height: parent.height
            control: module.control
        }

        QuickTilesModule {
            width: (parent.width - parent.spacing) / 2
            height: parent.height
            control: module.control
        }
    }
}
