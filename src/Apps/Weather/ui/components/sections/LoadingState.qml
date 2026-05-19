import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon
import "../../../AstreaI18n" as AstreaI18n

ColumnLayout {
    property var colors

    anchors.centerIn: parent
    spacing: 12

    UI.DisplayLabel {
        Layout.alignment: Qt.AlignHCenter
        text: "⛅"
        font.pixelSize: 48
        textColor: colors.primary
    }

    UI.TextLabel {
        Layout.alignment: Qt.AlignHCenter
        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.components.sections.loading_state.text.carregando"]) || "Loading...")
        font.pixelSize: 14
        textColor: colors.secondary
    }
}
