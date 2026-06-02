import QtQuick
import "../../../.."
import "../ControlCenterRegistry.js" as ModuleRegistry
import "../../../../../AstreaI18n" as AstreaI18n

Rectangle {
    id: library

    property var control: null
    readonly property real previewWidth: control ? control.popupWidth - control.cardPadding * 2 : 308
    readonly property real previewSpacing: control ? control.contentSpacing : Theme.spacing
    readonly property real previewCellWidth: (previewWidth - previewSpacing * 3) / 4
    readonly property int contentPadding: 22
    signal addRequested(string kind)
    signal doneRequested()

    width: parent ? parent.width : 720
    height: parent ? parent.height : 600
    radius: 24
    color: Theme.background
    border.width: 1
    border.color: Theme.border
    clip: true

    Flickable {
        id: contentFlick

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.margins: library.contentPadding
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn

            width: contentFlick.width
            spacing: 18

            WidgetSection {
                title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.widget_library_panel.title.conectividade"]) || "Connectivity")
                kinds: ["wifi", "bluetooth", "airdrop", "focus", "mirror"]
            }

            WidgetSection {
                title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.widget_library_panel.title.tela"]) || "Display")
                kinds: ["brightness"]
            }

            WidgetSection {
                title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.widget_library_panel.title.som"]) || "Sound")
                kinds: ["volume"]
            }

            WidgetSection {
                title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.widget_library_panel.title.madia"]) || "Media")
                kinds: ["media"]
            }
        }
    }

    Rectangle {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 50
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Rectangle {
            id: doneButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 18
            width: 70
            height: 30
            radius: height / 2
            color: doneArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.82) : Theme.accent
            border.width: 1
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.42)

            Behavior on color { ColorAnimation { duration: Theme.animationHover } }

            Text {
                anchors.centerIn: parent
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.widget_library_panel.text.done"]) || "Done")
                color: "#ffffff"
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold }
            }

            MouseArea {
                id: doneArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: library.doneRequested()
            }
        }
    }

    component WidgetSection: Column {
        property string title: ""
        property var kinds: []

        width: parent ? parent.width : library.previewWidth
        x: 0
        spacing: 10

        Text {
            width: parent.width
            text: title
            color: Theme.shellTextActive
            opacity: Theme.opacityEmphasis
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold }
        }

        Item {
            width: parent.width
            height: sectionFlow.implicitHeight

            Flow {
                id: sectionFlow

                width: parent.width
                spacing: library.previewSpacing

                Repeater {
                    model: kinds

                    WidgetTemplate {
                        control: library.control
                        widgetKind: modelData
                        widgetSize: ModuleRegistry.defaultSize(modelData)
                        width: library.previewCellWidth * ModuleRegistry.moduleSpan(modelData)
                            + library.previewSpacing * Math.max(0, ModuleRegistry.moduleSpan(modelData) - 1)
                        preferredHeight: ModuleRegistry.moduleHeight(modelData, ModuleRegistry.defaultSize(modelData))
                        onAddClicked: library.addRequested(modelData)
                    }
                }
            }
        }
    }
}
