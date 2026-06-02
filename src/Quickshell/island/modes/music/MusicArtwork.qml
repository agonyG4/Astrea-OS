import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property bool active: false
    property bool expanded: false
    property string artSource: ""
    property real flipScale: 1
    property int expandDuration: 420
    property int collapseDuration: 260

    visible: opacity > 0
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Rectangle {
        id: artClipMask
        anchors.fill: parent
        radius: root.expanded ? 12 : root.width / 2
        visible: false
        Behavior on radius { NumberAnimation { duration: root.expanded ? root.expandDuration : root.collapseDuration; easing.type: Easing.OutExpo } }
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: artClipMask
        }
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.flipScale
        }

        Image {
            anchors.fill: parent
            source: root.artSource
            sourceSize: Qt.size(Math.max(root.width, 96), Math.max(root.height, 96))
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            cache: false
            asynchronous: true
            opacity: source === "" || status === Image.Loading ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    states: [
        State {
            name: "expanded"
            when: root.expanded
            PropertyChanges { target: root; x: 18; y: 18; width: 60; height: 60 }
        },
        State {
            name: "compact"
            when: !root.expanded
            PropertyChanges { target: root; x: 8; y: 7; width: 20; height: 20 }
        }
    ]

    transitions: [
        Transition {
            from: "compact"
            to: "expanded"
            NumberAnimation { properties: "x,y,width,height"; duration: root.expandDuration; easing.type: Easing.OutExpo }
            NumberAnimation { target: artClipMask; property: "radius"; duration: root.expandDuration; easing.type: Easing.OutExpo }
        },
        Transition {
            from: "expanded"
            to: "compact"
            NumberAnimation { properties: "x,y,width,height"; duration: root.collapseDuration; easing.type: Easing.OutExpo }
            NumberAnimation { target: artClipMask; property: "radius"; duration: root.collapseDuration; easing.type: Easing.OutExpo }
        }
    ]
}
