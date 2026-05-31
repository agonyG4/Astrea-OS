import QtQuick

Item {
    id: store

    visible: false
    width: 0
    height: 0

    property alias visibleMessages: filteredModel
    property alias allMessages: mailModel
    property string selectedFolder: "Inbox"
    property string selectedMessageId: ""
    property string searchText: ""
    property string messageFilter: "all"
    property string statusText: "Connect Gmail"
    property var activeMessage: ({})
    property int modelRevision: 0
    readonly property bool hasActiveMessage: activeMessage !== null
        && activeMessage.messageId !== undefined
        && activeMessage.messageId !== ""

    function trim(value) {
        return (value || "").replace(/^\s+|\s+$/g, "")
    }

    function shorten(value, limit) {
        const text = trim(value || "").replace(/\s+/g, " ")
        if (text.length <= limit)
            return text
        return text.slice(0, limit - 1) + "..."
    }

    function copyMessage(item) {
        if (!item || item.messageId === undefined)
            return ({})
        return {
            messageId: item.messageId,
            folder: item.folder,
            fromName: item.fromName,
            fromAddress: item.fromAddress,
            subject: item.subject,
            preview: item.preview,
            body: item.body,
            htmlBody: item.htmlBody || "",
            htmlRenderMode: item.htmlRenderMode || (item.htmlBody ? "html" : "plain"),
            htmlSuppressed: !!item.htmlSuppressed,
            htmlLength: item.htmlLength || 0,
            htmlTableCount: item.htmlTableCount || 0,
            timestamp: item.timestamp,
            tag: item.tag,
            starred: item.starred,
            isRead: item.isRead,
            importance: item.importance,
            attachments: item.attachments || [],
            remoteImageCount: item.remoteImageCount || 0,
            remoteImagesLoadedCount: item.remoteImagesLoadedCount || 0,
            remoteImagesLoaded: !!item.remoteImagesLoaded
        }
    }

    function messageById(messageId) {
        const index = findIndex(messageId)
        return index >= 0 ? copyMessage(mailModel.get(index)) : ({})
    }

    function isLocalMessage(messageId) {
        return String(messageId || "").indexOf("local-") === 0
    }

    function findIndex(messageId) {
        for (let i = 0; i < mailModel.count; i++) {
            if (mailModel.get(i).messageId === messageId)
                return i
        }
        return -1
    }

    function folderCount(folder) {
        modelRevision
        let total = 0
        for (let i = 0; i < mailModel.count; i++) {
            const item = mailModel.get(i)
            if (folder === "Starred") {
                if (item.starred && item.folder !== "Trash")
                    total += 1
            } else if (folder === "All") {
                if (item.folder !== "Trash")
                    total += 1
            } else if (item.folder === folder) {
                total += 1
            }
        }
        return total
    }

    function unreadCount(folder) {
        modelRevision
        let total = 0
        for (let i = 0; i < mailModel.count; i++) {
            const item = mailModel.get(i)
            const inFolder = folder === "Starred"
                ? item.starred && item.folder !== "Trash"
                : (folder === "All" ? item.folder !== "Trash" : item.folder === folder)
            if (inFolder && !item.isRead)
                total += 1
        }
        return total
    }

    function starredCount(folder) {
        modelRevision
        let total = 0
        for (let i = 0; i < mailModel.count; i++) {
            const item = mailModel.get(i)
            const inFolder = folder === "Starred"
                ? item.starred && item.folder !== "Trash"
                : (folder === "All" ? item.folder !== "Trash" : item.folder === folder)
            if (inFolder && item.starred)
                total += 1
        }
        return total
    }

    function matchesFolder(item) {
        const inFolder = selectedFolder === "Starred"
            ? item.starred && item.folder !== "Trash"
            : (selectedFolder === "All" ? item.folder !== "Trash" : item.folder === selectedFolder)

        if (!inFolder)
            return false
        if (messageFilter === "unread")
            return !item.isRead
        if (messageFilter === "starred")
            return item.starred
        return true
    }

    function matchesSearch(item) {
        const query = trim(searchText).toLowerCase()
        if (query === "")
            return true
        const haystack = [
            item.fromName,
            item.fromAddress,
            item.subject,
            item.preview,
            item.body,
            item.tag
        ].join(" ").toLowerCase()
        return haystack.indexOf(query) !== -1
    }

    function syncActiveMessage() {
        activeMessage = ({})
        if (selectedMessageId === "")
            return

        const message = messageById(selectedMessageId)
        if (message.messageId)
            activeMessage = message
    }

    function rebuildMessages() {
        const previous = selectedMessageId
        let previousStillVisible = false
        filteredModel.clear()

        for (let i = 0; i < mailModel.count; i++) {
            const item = mailModel.get(i)
            if (matchesFolder(item) && matchesSearch(item)) {
                filteredModel.append(copyMessage(item))
                if (item.messageId === previous)
                    previousStillVisible = true
            }
        }

        if (!previousStillVisible)
            selectedMessageId = filteredModel.count > 0 ? filteredModel.get(0).messageId : ""

        syncActiveMessage()
        modelRevision += 1
    }

    function selectFolder(folder) {
        selectedFolder = folder
        if (folder === "Starred")
            messageFilter = "all"
        statusText = folderCount(folder) + " messages"
        rebuildMessages()
    }

    function setMessageFilter(filter) {
        messageFilter = filter
        rebuildMessages()
    }

    function setSearchText(value) {
        searchText = value
        rebuildMessages()
    }

    function clearFilters() {
        searchText = ""
        messageFilter = "all"
        rebuildMessages()
    }

    function selectMessage(messageId) {
        selectedMessageId = messageId
        setRead(messageId, true, false)
        syncActiveMessage()
        modelRevision += 1
    }

    function selectRelative(delta) {
        if (filteredModel.count === 0)
            return

        let index = 0
        for (let i = 0; i < filteredModel.count; i++) {
            if (filteredModel.get(i).messageId === selectedMessageId) {
                index = i
                break
            }
        }

        index = Math.max(0, Math.min(filteredModel.count - 1, index + delta))
        selectMessage(filteredModel.get(index).messageId)
    }

    function setFolder(messageId, folder, rebuild) {
        const index = findIndex(messageId)
        if (index < 0)
            return
        mailModel.setProperty(index, "folder", folder)
        statusText = folder === "Trash" ? "Moved to Trash" : "Moved to " + folder
        if (rebuild === undefined || rebuild)
            rebuildMessages()
    }

    function setStar(messageId, starred, rebuild) {
        const index = findIndex(messageId)
        if (index < 0)
            return
        mailModel.setProperty(index, "starred", starred)
        if (rebuild === undefined || rebuild)
            rebuildMessages()
    }

    function toggleStar(messageId) {
        const index = findIndex(messageId)
        if (index < 0)
            return
        setStar(messageId, !mailModel.get(index).starred)
    }

    function setRead(messageId, read, rebuild) {
        const index = findIndex(messageId)
        if (index < 0)
            return
        mailModel.setProperty(index, "isRead", read)
        if (rebuild === undefined || rebuild) {
            statusText = read ? "Marked as read" : "Marked as unread"
            rebuildMessages()
        }
    }

    function moveToInbox(messageId) {
        setFolder(messageId, "Inbox", false)
        selectedFolder = "Inbox"
        statusText = "Moved to Inbox"
        rebuildMessages()
    }

    function replaceMessages(messages, status) {
        mailModel.clear()
        for (let i = 0; i < messages.length; i++)
            mailModel.append(normalized(messages[i]))
        statusText = status || "Gmail synced"
        selectedMessageId = mailModel.count > 0 ? mailModel.get(0).messageId : ""
        rebuildMessages()
    }

    function appendMessages(messages, status) {
        for (let i = 0; i < messages.length; i++) {
            const message = normalized(messages[i])
            if (findIndex(message.messageId) < 0)
                mailModel.append(message)
        }
        statusText = status || "More Gmail messages loaded"
        rebuildMessages()
    }

    function applyRemoteMessage(message) {
        const normalizedMessage = normalized(message)
        const index = findIndex(normalizedMessage.messageId)
        if (index < 0)
            return
        const keys = ["folder", "fromName", "fromAddress", "subject", "preview", "body", "htmlBody", "htmlRenderMode", "htmlSuppressed", "htmlLength", "htmlTableCount", "timestamp", "tag", "starred", "isRead", "importance", "attachments", "remoteImageCount", "remoteImagesLoadedCount", "remoteImagesLoaded"]
        for (let i = 0; i < keys.length; i++)
            mailModel.setProperty(index, keys[i], normalizedMessage[keys[i]])
        rebuildMessages()
    }

    function normalized(item) {
        return {
            messageId: item.messageId || ("local-message-" + Date.now()),
            folder: item.folder || "Inbox",
            fromName: item.fromName || "Unknown Sender",
            fromAddress: item.fromAddress || "",
            subject: item.subject || "(No subject)",
            preview: item.preview || "",
            body: item.body || item.preview || "",
            htmlBody: item.htmlBody || "",
            htmlRenderMode: item.htmlRenderMode || (item.htmlBody ? "html" : "plain"),
            htmlSuppressed: !!item.htmlSuppressed,
            htmlLength: item.htmlLength || 0,
            htmlTableCount: item.htmlTableCount || 0,
            timestamp: item.timestamp || "",
            tag: item.tag || "Mail",
            starred: !!item.starred,
            isRead: item.isRead === undefined ? true : !!item.isRead,
            importance: item.importance || "normal",
            attachments: item.attachments || [],
            remoteImageCount: item.remoteImageCount || 0,
            remoteImagesLoadedCount: item.remoteImagesLoadedCount || 0,
            remoteImagesLoaded: !!item.remoteImagesLoaded
        }
    }

    Component.onCompleted: rebuildMessages()

    ListModel {
        id: filteredModel
    }

    ListModel {
        id: mailModel
    }
}
