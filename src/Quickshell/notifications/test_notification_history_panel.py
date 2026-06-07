#!/usr/bin/env python3
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
NOTIFICATIONS = ROOT / "notifications"
BAR = ROOT / "bar"


class NotificationHistoryPanelTests(unittest.TestCase):
    def test_daemon_persists_history_and_exposes_clear_methods(self):
        source = (NOTIFICATIONS / "notification_daemon.py").read_text()

        self.assertIn('"history": list(self.history.values())', source)
        self.assertIn("def ClearHistoryItem", source)
        self.assertIn("def ClearHistory", source)
        self.assertIn("MAX_HISTORY", source)

    def test_store_loads_history_and_can_clear_it(self):
        source = (NOTIFICATIONS / "core" / "NotificationStore.qml").read_text()

        self.assertIn("property alias historyModel", source)
        self.assertIn("property alias historyCount", source)
        self.assertIn("function syncHistory", source)
        self.assertIn("function historyIndexFor", source)
        self.assertIn("notificationHistoryModel.insert", source)
        self.assertIn("notificationHistoryModel.move", source)
        self.assertNotIn("function syncHistory(items) {\n        notificationHistoryModel.clear()", source)
        self.assertIn("function clearHistoryItem", source)
        self.assertIn("function clearHistory", source)
        self.assertIn("payload.history || payload.notifications", source)

    def test_clock_opens_notification_history_popup(self):
        clock = (BAR / "ui" / "components" / "system" / "base" / "Clock.qml").read_text()
        bar = (BAR / "Bar.qml").read_text()

        self.assertIn("property var popupHost", clock)
        self.assertIn("function _toggleNotifications", clock)
        self.assertIn("width: clockButton.width", clock)
        self.assertIn("TopbarIndicator", clock)
        self.assertNotIn("id: clockMouse", clock)
        self.assertIn("popupHost: notificationPopupHost", bar)
        self.assertIn("NotificationHistoryPanel", bar)

    def test_history_panel_has_per_item_x_and_clear_all(self):
        panel = (NOTIFICATIONS / "ui" / "NotificationHistoryPanel.qml").read_text()
        card = (NOTIFICATIONS / "ui" / "NotificationCard.qml").read_text()
        qmldir = (NOTIFICATIONS / "ui" / "qmldir").read_text()

        self.assertIn("NotificationHistoryPanel 1.0 NotificationHistoryPanel.qml", qmldir)
        self.assertIn("Limpar tudo", panel)
        self.assertIn("clearHistory()", panel)
        self.assertIn("floatingAccessory: Component", panel)
        self.assertIn("implicitWidth: notificationStore.historyCount > 0 ? clearAllRow.implicitWidth + 22 : 0", panel)
        self.assertIn("color: clearAllArea.containsMouse ? Theme.surface : Theme.background", panel)
        self.assertIn("border.color: Theme.border", panel)
        self.assertIn("font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeSmall }", panel)
        self.assertIn("NotificationCard", panel)
        self.assertIn("popupWidth: 384", panel)
        self.assertIn("readonly property int notificationCardHeight: 92", panel)
        self.assertIn("readonly property int notificationSpacing: 10", panel)
        self.assertIn("spacing: panel.notificationSpacing", panel)
        self.assertIn("clip: true", panel)
        self.assertIn("height: Math.max(panel.notificationCardHeight, notificationCard.implicitHeight)", panel)
        self.assertIn("interactive: contentHeight > height", panel)
        self.assertIn("height: notificationStore.historyCount > 0 ? historyList.height : 92", panel)
        self.assertIn("color: Theme.background", panel)
        self.assertIn("text: panel.hiddenCount + \" notificacoes a mais\"", panel)
        self.assertIn("autoDismissEnabled: false", panel)
        self.assertIn("onCloseRequested: notificationId => notificationStore.clearHistoryItem(notificationId)", panel)
        self.assertNotIn("Qt.rgba(0.42, 0.42, 0.40", panel)
        self.assertNotIn("Qt.rgba(0.54, 0.54, 0.51", panel)
        self.assertIn("property bool autoDismissEnabled", card)
        self.assertIn("color: urgency >= 2 ? Qt.rgba(0.22, 0.06, 0.045, 0.92) : Theme.background", card)
        self.assertIn("text: appIcon.length > 0 ? appIcon.slice(0, 1).toUpperCase() : appName.slice(0, 1).toUpperCase()", card)


if __name__ == "__main__":
    unittest.main()
