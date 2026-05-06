import QtQuick
import "components/system"
import "components/bluetooth"
import "components/controlcenter"
import "components/network"
import "components/volume"
import ".."

Item {
    id: root

    property var astreaPopupRef: null
    property bool netConnected: false
    property string netType: "none"
    property var netPopupRef: null
    property bool btOn: false
    property string btDevicesJson: "[]"
    property bool btScanning: false
    property var btPopupRef: null
    property int volLevel: 50
    property bool volMuted: false
    property var volPopupRef: null
    property var ccPopupRef: null

    readonly property string quickshellAssetRoot: "file:///home/agony/.local/share/Astrea/Assets/ui/quickshell/bar/"
    readonly property int pillHeight: 36
    readonly property int sidePadding: 10
    readonly property int rightWidth: Math.min(Math.max(0, root.width - leftSection.width - 28), rightRow.implicitWidth + 20)

    property string _lastClockText: ""
    property string _lastDateText: ""

    signal volChangeRequested(int v)
    signal astreaPopupRequested(real anchorX)
    signal netPopupRequested(real anchorX)
    signal btPopupRequested(real anchorX)
    signal volPopupRequested(real anchorX)
    signal ccPopupRequested(real anchorX)

    function logoCenterX() {
        return logoButton.mapToItem(null, logoButton.width / 2, logoButton.height / 2).x
    }

    function updateAstreaAnchor() {
        if (!root.astreaPopupRef) return
        root.astreaPopupRef.anchorX = logoCenterX()
    }

    function tick() {
        const now = new Date()
        const h = now.getHours()
        const nextClockText = `${(h % 12 || 12).toString().padStart(2, "0")}:${now.getMinutes().toString().padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`
        const nextDateText = `${root._days[now.getDay()]} ${root._months[now.getMonth()]} ${now.getDate()}`

        if (nextClockText !== root._lastClockText) {
            root._lastClockText = nextClockText
            clockLabel.text = nextClockText
        }
        if (nextDateText !== root._lastDateText) {
            root._lastDateText = nextDateText
            dateLabel.text = nextDateText
        }
    }

    readonly property var _days: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"]
    readonly property var _months: ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]

    onXChanged: updateAstreaAnchor()
    onWidthChanged: updateAstreaAnchor()
    onAstreaPopupRefChanged: updateAstreaAnchor()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.tick()
    }

    Component.onCompleted: {
        root.tick()
        updateAstreaAnchor()
        appearAnim.start()
    }

    NumberAnimation {
        id: appearAnim
        targets: [leftSection, rightSection]
        property: "opacity"
        from: 0
        to: 1
        duration: 400
        easing.type: Easing.OutCubic
    }

    Item {
        id: leftSection
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: root.pillHeight
        width: leftRow.implicitWidth + root.sidePadding * 2
        opacity: 0

        HoverHandler { id: leftHover }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLarge - 2
            color: Theme.background
            border.width: 1
            border.color: leftHover.hovered ? Theme.barBorderHover : Theme.border

            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        Row {
            id: leftRow
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                id: logoButton
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: Theme.radiusMedium
                color: logoArea.containsMouse ? Theme.separator : "transparent"

                Image {
                    anchors.centerIn: parent
                    source: root.quickshellAssetRoot + "astrea.png"
                    width: 18
                    height: 18
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.80
                }

                MouseArea {
                    id: logoArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.astreaPopupRef) {
                            root.astreaPopupRef.toggleAt(root.logoCenterX())
                        } else {
                            root.astreaPopupRequested(root.logoCenterX())
                        }
                    }
                }
            }

            Workspaces { anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Item {
        id: rightSection
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.pillHeight
        width: root.rightWidth
        opacity: 0
        clip: true

        HoverHandler { id: rightHover }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLarge - 2
            color: Theme.background
            border.width: 1
            border.color: rightHover.hovered ? Theme.barBorderHover : Theme.border

            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        Row {
            id: rightRow
            anchors.centerIn: parent
            spacing: 0

            Tray {
                id: trayComp
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: trayComp.width > 0 ? 8 : 0
                height: 36
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                NetworkIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    netConnected: root.netConnected
                    netType: root.netType
                    netPopupRef: root.netPopupRef
                    onClicked: anchorX => { if (!root.netPopupRef) root.netPopupRequested(anchorX) }
                }

                BluetoothIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    btOn: root.btOn
                    devicesJson: root.btDevicesJson
                    scanning: root.btScanning
                    btPopupRef: root.btPopupRef
                    onClicked: anchorX => { if (!root.btPopupRef) root.btPopupRequested(anchorX) }
                }

                VolumeIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    volLevel: root.volLevel
                    volMuted: root.volMuted
                    volPopupRef: root.volPopupRef
                    onVolChanged: (v) => root.volChangeRequested(v)
                    onClicked: anchorX => { if (!root.volPopupRef) root.volPopupRequested(anchorX) }
                }

                ControlCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    ccPopupRef: root.ccPopupRef
                    onClicked: anchorX => { if (!root.ccPopupRef) root.ccPopupRequested(anchorX) }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: Theme.separator
            }

            Item {
                width: dateLabel.implicitWidth + 16
                height: 36

                Text {
                    id: dateLabel
                    anchors.fill: parent
                    color: Theme.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font {
                        family: Theme.fontFamilyDisplay
                        pixelSize: Theme.fontSizeSmall
                        weight: Font.Medium
                        letterSpacing: 0.3
                    }
                    renderType: Text.NativeRendering

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: dateLabel; property: "opacity"; to: 0; duration: 120 }
                            NumberAnimation { target: dateLabel; property: "opacity"; to: 1; duration: 120 }
                        }
                    }
                }
            }

            Item {
                width: clockLabel.implicitWidth + 20
                height: 36

                Text {
                    id: clockLabel
                    anchors.fill: parent
                    color: Theme.textActive
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font {
                        family: Theme.fontFamilyDisplay
                        pixelSize: Theme.fontSizeTitle
                        weight: Font.Medium
                        letterSpacing: 0.35
                    }
                    renderType: Text.NativeRendering

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: clockLabel; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InQuad }
                            NumberAnimation { target: clockLabel; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
