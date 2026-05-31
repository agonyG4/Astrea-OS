import QtQuick
import "../../../.."
import "../../../../../AstreaI18n" as AstreaI18n

Item {
    id: module

    property var control: null

    Column {
        anchors.fill: parent
        spacing: Theme.spacing

        ControlTile {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3
            icon: "󰘶"
            title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.quick_tiles_module.title.foco"]) || "Focus")
            subtitle: module.control && module.control.focusOn
                ? AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.active", "Active")
                : AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.inactive", "Inactive")
            active: module.control ? module.control.focusOn : false
            onClicked: if (module.control) module.control.focusOn = !module.control.focusOn
        }

        ControlTile {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3
            icon: "󰍺"
            title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.quick_tiles_module.title.espelhar"]) || "Mirror")
            subtitle: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.quick_tiles_module.subtitle.tela"]) || "Display")
            active: false
        }

        ControlTile {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3
            icon: module.control ? module.control.volumeIcon() : "󰕾"
            title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.quick_tiles_module.title.som"]) || "Sound")
            subtitle: module.control && module.control.masterMuted
                ? AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.muted", "Muted")
                : (module.control ? module.control.masterVol + "%" : "0%")
            active: module.control ? !module.control.masterMuted && module.control.masterVol > 0 : false
            onClicked: if (module.control) module.control.toggleMute()
        }
    }
}
