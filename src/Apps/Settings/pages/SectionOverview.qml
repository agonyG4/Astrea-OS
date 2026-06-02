import QtQuick
import QtQuick.Layouts
import Quickshell
import "../AstreaComponents"

Item {
    id: root

    property string sectionTitle: ""
    property var groups: []
    property int sidebarIndex: -1

    signal navigateToPage(int pageIndex, int sidebarIndex)

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBorder: Theme.cardBorder
    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT")
        || (Quickshell.env("HOME") + "/.local/share/Astrea")

    function iconSourceFor(iconKey) {
        if (!iconKey || iconKey.length === 0)
            return ""
        if (Theme.iconTheme !== "")
            return "file://" + astreaRoot + "/Assets/icons/settings/themes/" + Theme.iconTheme + "/" + iconKey + ".svg"
        return "file://" + astreaRoot + "/Assets/icons/settings/" + iconKey + ".svg"
    }

    ScrollPage {
        anchors.fill: parent
        contentMargins: 28
        maxWidth: 640

        Text {
            text: root.sectionTitle
            color: root.textPrimary
            font.family: "SF Pro Display"
            font.pixelSize: 24
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            Layout.bottomMargin: 20
            elide: Text.ElideRight
        }

        Repeater {
            model: root.groups
            delegate: ColumnLayout {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.bottomMargin: index === root.groups.length - 1 ? 0 : 18
                spacing: 8

                Text {
                    visible: !!modelData.title && modelData.title.length > 0
                    text: modelData.title || ""
                    color: root.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Theme.fontWeightDemiBold
                    Layout.leftMargin: 4
                    Layout.bottomMargin: 2
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 10
                    color: Theme.cardBg
                    border.width: 1
                    border.color: root.cardBorder
                    implicitHeight: rowsColumn.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: rowsColumn
                        readonly property int itemCount: (modelData.items || []).length
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0

                        Repeater {
                            model: modelData.items || []
                            delegate: Item {
                                id: row
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                implicitHeight: 58

                                Rectangle {
                                    anchors {
                                        fill: parent
                                        leftMargin: 4
                                        rightMargin: 4
                                        topMargin: 3
                                        bottomMargin: 3
                                    }
                                    radius: 8
                                    color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 16
                                        rightMargin: 14
                                    }
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 7
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.08)

                                        Image {
                                            anchors.fill: parent
                                            source: root.iconSourceFor(row.modelData.iconKey || "")
                                            visible: source !== ""
                                            sourceSize: Qt.size(56, 56)
                                            fillMode: Image.Stretch
                                            smooth: true
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: (row.modelData.iconKey || "") === ""
                                            text: row.modelData.sym || ""
                                            color: root.textSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontSizeNormal
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 2

                                        Text {
                                            text: row.modelData.label || ""
                                            color: root.textPrimary
                                            font.family: "SF Pro Display"
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: !!row.modelData.sublabel && row.modelData.sublabel.length > 0
                                            text: row.modelData.sublabel || ""
                                            color: root.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: "›"
                                        color: root.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 20
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                Rectangle {
                                    visible: row.index < rowsColumn.itemCount - 1
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        leftMargin: 56
                                    }
                                    height: 1
                                    color: root.cardBorder
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.navigateToPage(row.modelData.pageIndex, root.sidebarIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
