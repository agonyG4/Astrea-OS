import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import "AstreaComponents" as Astrea
import "components" as Email
import "services" as Services
import "state" as State

ApplicationWindow {
    id: root

    visible: true
    width: 1280
    height: 760
    minimumWidth: 920
    minimumHeight: 560
    maximumWidth: 1400
    maximumHeight: 820
    title: "Email"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    font.family: Astrea.Theme.fontFamily
    font.pixelSize: Astrea.Theme.fontSizeNormal
    font.weight: Astrea.Theme.fontWeightNormal
    background: Rectangle { color: "transparent" }
    onClosing: Qt.quit()

    readonly property int pagePad: Astrea.Theme.pageMargin
    readonly property int sidebarWidth: sidebarCollapsed ? 58 : 206
    readonly property int listWidth: width < 1060 ? 350 : 392
    readonly property color selectedBg: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.16)
    readonly property color selectedBorder: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.34)
    readonly property color softSurface: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.025) : Qt.rgba(1, 1, 1, 0.035)
    readonly property color hoverSurface: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.045) : Qt.rgba(1, 1, 1, 0.060)
    readonly property bool composeReady: trim(composeTo) !== "" && trim(composeSubject) !== ""
    readonly property string accountLabel: gmail.authenticated
        ? (gmail.account !== "" ? gmail.account : "Gmail connected")
        : ""

    property bool sidebarCollapsed: false
    property bool composeOpen: false
    property bool settingsOpen: false
    property string composeTo: ""
    property string composeSubject: ""
    property string composeBody: ""
    property bool mailLoadingMore: false
    property bool mailForceRefreshPages: false
    property string mailNextPageToken: ""
    property int mailResultSizeEstimate: 0

    function trim(value) {
        return (value || "").replace(/^\s+|\s+$/g, "")
    }

    function shorten(value, limit) {
        const text = trim(value || "").replace(/\s+/g, " ")
        if (text.length <= limit)
            return text
        return text.slice(0, limit - 1) + "..."
    }

    function canSync(messageId) {
        return gmail.authenticated && !mail.isLocalMessage(messageId)
    }

    function refreshMailbox(forceRefresh) {
        const shouldRefresh = forceRefresh === true
        mailLoadingMore = false
        mailForceRefreshPages = shouldRefresh
        mailNextPageToken = ""
        mailResultSizeEstimate = 0
        if (gmail.authenticated) {
            mail.statusText = shouldRefresh ? "Refreshing Gmail" : "Loading saved mail"
            gmail.list(mail.selectedFolder, mail.messageFilter, mail.searchText, "", 100, shouldRefresh, !shouldRefresh)
        } else {
            mail.statusText = "0 messages"
            mail.rebuildMessages()
        }
    }

    function loadedStatus() {
        const estimate = mailResultSizeEstimate
        const loaded = mail.allMessages.count
        if (estimate > loaded)
            return "Loaded " + loaded + " of " + estimate
        return loaded + " messages loaded"
    }

    function loadMoreMessages() {
        if (!gmail.authenticated || gmail.busy || mailNextPageToken === "")
            return
        mailLoadingMore = true
        mail.statusText = "Loading more Gmail messages"
        gmail.list(mail.selectedFolder, mail.messageFilter, mail.searchText, mailNextPageToken, 100, mailForceRefreshPages, false)
    }

    function showGmailDetails() {
        settingsOpen = true
        mail.statusText = "Credentials: " + gmail.credentialsPath
    }

    function selectFolder(folder) {
        settingsOpen = false
        mail.selectFolder(folder)
        refreshMailbox(false)
    }

    function setMessageFilter(filter) {
        mail.setMessageFilter(filter)
        refreshMailbox(false)
    }

    function updateSearch(value) {
        mail.setSearchText(value)
        if (gmail.authenticated)
            searchDebounce.restart()
    }

    function clearFilters() {
        mail.clearFilters()
        refreshMailbox(false)
    }

    function selectMessage(messageId) {
        const previous = mail.messageById(messageId)
        mail.selectMessage(messageId)
        if (previous.messageId && !previous.isRead && canSync(messageId))
            gmail.modify(messageId, "read")
    }

    function loadActiveImages() {
        const messageId = mail.activeMessage.messageId || ""
        if (messageId === "" || !canSync(messageId))
            return
        mail.statusText = "Loading images"
        gmail.get(messageId, true)
    }

    function selectRelative(delta) {
        if (mail.visibleMessages.count === 0)
            return

        let index = 0
        for (let i = 0; i < mail.visibleMessages.count; i++) {
            if (mail.visibleMessages.get(i).messageId === mail.selectedMessageId) {
                index = i
                break
            }
        }

        index = Math.max(0, Math.min(mail.visibleMessages.count - 1, index + delta))
        selectMessage(mail.visibleMessages.get(index).messageId)
    }

    function toggleStar(messageId) {
        const previous = mail.messageById(messageId)
        if (!previous.messageId)
            return
        mail.toggleStar(messageId)
        if (canSync(messageId))
            gmail.modify(messageId, previous.starred ? "unstar" : "star")
    }

    function archiveActive() {
        const messageId = mail.activeMessage.messageId || ""
        if (messageId === "")
            return
        mail.setFolder(messageId, "Archive")
        if (canSync(messageId))
            gmail.modify(messageId, "archive")
    }

    function trashActive() {
        const messageId = mail.activeMessage.messageId || ""
        if (messageId === "")
            return
        mail.setFolder(messageId, "Trash")
        if (canSync(messageId))
            gmail.modify(messageId, "trash")
    }

    function moveActiveToInbox() {
        const messageId = mail.activeMessage.messageId || ""
        if (messageId === "")
            return
        mail.moveToInbox(messageId)
        if (canSync(messageId))
            gmail.modify(messageId, "inbox")
    }

    function setActiveRead(read) {
        const messageId = mail.activeMessage.messageId || ""
        if (messageId === "")
            return
        mail.setRead(messageId, read)
        if (canSync(messageId))
            gmail.modify(messageId, read ? "read" : "unread")
    }

    function openCompose(mode) {
        if (mode === "reply" && mail.activeMessage && mail.activeMessage.messageId) {
            composeTo = mail.activeMessage.fromAddress
            composeSubject = mail.activeMessage.subject.indexOf("Re:") === 0 ? mail.activeMessage.subject : "Re: " + mail.activeMessage.subject
            composeBody = "\n\nOn " + mail.activeMessage.timestamp + ", " + mail.activeMessage.fromName + " wrote:\n> " + shorten(mail.activeMessage.body, 220)
        } else {
            composeTo = ""
            composeSubject = ""
            composeBody = ""
        }
        composeOpen = true
    }

    function closeCompose() {
        composeOpen = false
    }

    function sendDraft() {
        const to = trim(composeTo)
        const subject = trim(composeSubject)
        const body = trim(composeBody)
        if (to === "" || subject === "") {
            mail.statusText = "Add recipient and subject"
            return
        }

        if (gmail.authenticated) {
            mail.statusText = "Sending via Gmail"
            gmail.send(to, subject, body)
        } else {
            mail.statusText = "Connect Gmail to send"
        }
    }

    Timer {
        id: searchDebounce
        interval: 350
        repeat: false
        onTriggered: root.refreshMailbox(false)
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: root.openCompose("new")
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: searchBox.focusField(true)
    }

    Shortcut {
        sequence: "Ctrl+Down"
        onActivated: root.selectRelative(1)
    }

    Shortcut {
        sequence: "Ctrl+Up"
        onActivated: root.selectRelative(-1)
    }

    State.MailStore {
        id: mail
    }

    Services.EmailCliClient {
        id: gmail

        onStatusReady: payload => {
            if (payload.authenticated) {
                mail.statusText = payload.account || "Gmail ready"
                root.refreshMailbox(false)
            } else {
                mail.statusText = "0 messages"
            }
        }

        onAuthReady: payload => {
            mail.statusText = payload.account ? "Connected: " + payload.account : "Gmail connected"
            root.refreshMailbox(true)
        }

        onMessagesReady: payload => {
            root.mailNextPageToken = payload.nextPageToken || ""
            root.mailResultSizeEstimate = payload.resultSizeEstimate || 0
            if (root.mailLoadingMore)
                mail.appendMessages(payload.messages || [], "Gmail synced")
            else
                mail.replaceMessages(payload.messages || [], "Gmail synced")
            root.mailLoadingMore = false
            mail.statusText = root.loadedStatus()
        }

        onSendReady: payload => {
            root.composeOpen = false
            root.composeTo = ""
            root.composeSubject = ""
            root.composeBody = ""
            mail.statusText = "Sent via Gmail"
            mail.selectFolder("Sent")
            root.refreshMailbox(true)
        }

        onModifyReady: payload => {
            if (payload.message && payload.message.messageId)
                mail.applyRemoteMessage(payload.message)
        }

        onMessageReady: payload => {
            if (payload.message && payload.message.messageId)
                mail.applyRemoteMessage(payload.message)
        }

        onFailed: (action, message) => {
            root.mailLoadingMore = false
            mail.statusText = message
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        color: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.24) : Qt.rgba(0, 0, 0, 0.6)
            shadowBlur: 1.0
            shadowVerticalOffset: 8
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Astrea.Theme.windowBackground
        border.width: 1
        border.color: Astrea.Theme.windowBorder
        clip: true

        Item {
            id: sceneLayer
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Astrea.Theme.windowWash
            }

            MouseArea {
                property point pressPos
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 54
                cursorShape: Qt.SizeAllCursor
                onPressed: mouse => pressPos = Qt.point(mouse.x, mouse.y)
                onPositionChanged: mouse => {
                    if (pressed) {
                        root.setX(root.x + mouse.x - pressPos.x)
                        root.setY(root.y + mouse.y - pressPos.y)
                    }
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    margins: root.pagePad
                }
                spacing: Astrea.Theme.spacingLarge

                Email.EmailSidebar {
                    Layout.preferredWidth: root.sidebarWidth
                    Layout.fillHeight: true
                    collapsed: root.sidebarCollapsed
                    statusText: gmail.busy ? "Gmail working" : mail.statusText
                    selectedFolder: mail.selectedFolder
                    settingsOpen: root.settingsOpen
                    inboxUnread: mail.unreadCount("Inbox")
                    draftsCount: mail.folderCount("Drafts")
                    onComposeRequested: root.openCompose("new")
                    onFolderRequested: folder => root.selectFolder(folder)
                    onCollapseRequested: collapsed => root.sidebarCollapsed = collapsed
                    onSettingsRequested: root.settingsOpen = true

                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: Astrea.Theme.animationNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Astrea.Theme.spacingLarge

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Astrea.Theme.spacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Astrea.Theme.spacingTiny

                            Astrea.DisplayLabel {
                                text: root.settingsOpen ? "Settings" : "Email"
                                textColor: Astrea.Theme.textPrimary
                                font.pixelSize: Astrea.Theme.fontSizeHeader
                                font.weight: Astrea.Theme.fontWeightDemiBold
                            }

                            Astrea.TextLabel {
                                Layout.fillWidth: true
                                text: root.settingsOpen
                                    ? "Gmail account, OAuth credentials and backend sync"
                                    : (mail.selectedFolder === "All" ? "All Mail" : mail.selectedFolder)
                                    + " • " + mail.visibleMessages.count + " shown"
                                    + " • " + mail.unreadCount(mail.selectedFolder) + " unread"
                                    + (root.accountLabel !== "" ? " • " + root.accountLabel : "")
                                textColor: Astrea.Theme.textSecondary
                                font.pixelSize: Astrea.Theme.fontSizeNormal
                                elide: Text.ElideRight
                            }
                        }

                        Email.MetricPill {
                            visible: !root.settingsOpen
                            label: "Unread"
                            value: mail.unreadCount(mail.selectedFolder)
                            surfaceColor: root.softSurface
                        }

                        Email.MetricPill {
                            visible: !root.settingsOpen
                            label: "Starred"
                            value: mail.starredCount(mail.selectedFolder)
                            surfaceColor: root.softSurface
                        }

                        Astrea.SearchField {
                            id: searchBox
                            visible: !root.settingsOpen
                            Layout.preferredWidth: Math.min(330, Math.max(220, root.width * 0.24))
                            placeholderText: "Search mail"
                            text: mail.searchText
                            onTextEdited: value => root.updateSearch(value)
                            onCleared: root.clearFilters()
                        }

                        Astrea.Button {
                            visible: !root.settingsOpen
                            text: ""
                            iconText: "\uf01e"
                            iconFontFamily: "JetBrainsMono Nerd Font"
                            controlWidth: 38
                            controlHeight: 36
                            flat: true
                            enabled: !gmail.busy
                            onClicked: root.refreshMailbox(true)
                        }

                        Astrea.Button {
                            visible: !root.settingsOpen
                            text: "Compose"
                            iconText: "\uf304"
                            iconFontFamily: "JetBrainsMono Nerd Font"
                            primary: true
                            onClicked: root.openCompose("new")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Astrea.Theme.spacingLarge
                        visible: !root.settingsOpen

                        Email.MessageListPane {
                            Layout.preferredWidth: root.listWidth
                            Layout.fillHeight: true
                            messagesModel: mail.visibleMessages
                            selectedFolder: mail.selectedFolder
                            selectedMessageId: mail.selectedMessageId
                            searchText: mail.searchText
                            messageFilter: mail.messageFilter
                            emptyIcon: "\uf0e0"
                            emptyTitle: "You dont have any messages"
                            unreadCount: mail.unreadCount(mail.selectedFolder)
                            starredCount: mail.starredCount(mail.selectedFolder)
                            canLoadMore: root.mailNextPageToken !== ""
                            loadingMore: root.mailLoadingMore
                            resultLabel: root.mailResultSizeEstimate > mail.allMessages.count
                                ? mail.allMessages.count + " of " + root.mailResultSizeEstimate
                                : ""
                            selectedBg: root.selectedBg
                            selectedBorder: root.selectedBorder
                            softSurface: root.softSurface
                            hoverSurface: root.hoverSurface
                            onFilterRequested: filter => root.setMessageFilter(filter)
                            onMessageRequested: messageId => root.selectMessage(messageId)
                            onClearFiltersRequested: root.clearFilters()
                            onLoadMoreRequested: root.loadMoreMessages()
                        }

                        Email.MessageDetailPane {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            message: mail.activeMessage
                            hasMessage: mail.hasActiveMessage
                            softSurface: root.softSurface
                            onReplyRequested: root.openCompose("reply")
                            onStarRequested: messageId => root.toggleStar(messageId)
                            onArchiveRequested: root.archiveActive()
                            onMarkReadRequested: read => root.setActiveRead(read)
                            onMoveToInboxRequested: root.moveActiveToInbox()
                            onTrashRequested: root.trashActive()
                            onLoadImagesRequested: root.loadActiveImages()
                        }
                    }

                    Email.SetupPanel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.settingsOpen
                        configured: gmail.configured
                        authenticated: gmail.authenticated
                        busy: gmail.busy
                        account: gmail.account
                        credentialsPath: gmail.credentialsPath
                        tokenPath: gmail.tokenPath
                        statusMessage: gmail.statusMessage
                        softSurface: root.softSurface
                        onConnectRequested: gmail.authenticate()
                        onRefreshRequested: gmail.refreshStatus()
                        onDetailsRequested: root.showGmailDetails()
                    }
                }
            }
        }

        Email.ComposerSheet {
            anchors.fill: parent
            z: 80
            visible: root.composeOpen
            to: root.composeTo
            subject: root.composeSubject
            messageBody: root.composeBody
            statusText: gmail.busy ? "Gmail working" : mail.statusText
            canSend: root.composeReady && !gmail.busy
            softSurface: root.softSurface
            onCloseRequested: root.closeCompose()
            onToEdited: value => root.composeTo = value
            onSubjectEdited: value => root.composeSubject = value
            onBodyEdited: value => root.composeBody = value
            onSendRequested: root.sendDraft()
        }
    }
}
