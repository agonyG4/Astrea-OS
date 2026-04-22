pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool   netConnected:  false
    property string netType:       "none"
    property string netSsid:       ""
    property string netDownload:   "0 B/s"
    property string netUpload:     "0 B/s"
    property bool   btOn:          false
    property string btDevicesJson: "[]"
    property string btScannedJson: "[]"
    property bool   btScanning:    false
    property int    volLevel:      50
    property bool   volMuted:      false
}
