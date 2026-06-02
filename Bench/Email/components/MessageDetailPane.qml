import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Rectangle {
    id: pane

    property var message: ({})
    property bool hasMessage: false
    property color softSurface: Astrea.Theme.cardBg
    signal replyRequested()
    signal starRequested(string messageId)
    signal archiveRequested()
    signal markReadRequested(bool read)
    signal moveToInboxRequested()
    signal trashRequested()
    signal loadImagesRequested()

    radius: Astrea.Theme.cardRadius
    color: Astrea.Theme.cardBg
    border.width: 1
    border.color: Astrea.Theme.cardBorder
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Astrea.Theme.spacingXLarge
        spacing: Astrea.Theme.spacingLarge
        visible: pane.hasMessage

        RowLayout {
            Layout.fillWidth: true
            spacing: Astrea.Theme.spacingLarge

            AvatarBubble {
                initials: pane.initials(pane.message.fromName || "Mail")
                tag: pane.message.tag || ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Astrea.DisplayLabel {
                    Layout.fillWidth: true
                    text: pane.message.subject || ""
                    textColor: Astrea.Theme.textPrimary
                    font.pixelSize: Astrea.Theme.fontSizeHeader
                    font.weight: Astrea.Theme.fontWeightDemiBold
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Astrea.TextLabel {
                        text: pane.message.fromName || ""
                        textColor: Astrea.Theme.textPrimary
                        font.pixelSize: Astrea.Theme.fontSizeNormal
                        font.weight: Astrea.Theme.fontWeightDemiBold
                    }

                    Astrea.TextLabel {
                        Layout.fillWidth: true
                        text: pane.message.fromAddress ? "<" + pane.message.fromAddress + ">" : ""
                        textColor: Astrea.Theme.textSecondary
                        font.pixelSize: Astrea.Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Astrea.TextLabel {
                        text: pane.message.timestamp || ""
                        textColor: Astrea.Theme.textTertiary
                        font.pixelSize: Astrea.Theme.fontSizeSmall
                    }
                }
            }

            Astrea.Button {
                text: ""
                iconText: pane.message.starred ? "\uf005" : "\uf006"
                iconFontFamily: "JetBrainsMono Nerd Font"
                controlWidth: 38
                controlHeight: 36
                flat: true
                onClicked: pane.starRequested(pane.message.messageId || "")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Astrea.Theme.spacing

            Astrea.Button {
                text: "Reply"
                iconText: "\uf112"
                iconFontFamily: "JetBrainsMono Nerd Font"
                onClicked: pane.replyRequested()
            }

            Astrea.Button {
                text: "Archive"
                iconText: "\uf187"
                iconFontFamily: "JetBrainsMono Nerd Font"
                enabled: pane.message.folder !== "Archive"
                onClicked: pane.archiveRequested()
            }

            Astrea.Button {
                text: pane.message.isRead ? "Mark unread" : "Mark read"
                iconText: pane.message.isRead ? "\uf0e0" : "\uf2b6"
                iconFontFamily: "JetBrainsMono Nerd Font"
                onClicked: pane.markReadRequested(!pane.message.isRead)
            }

            Astrea.Button {
                visible: pane.message.folder === "Trash" || pane.message.folder === "Archive"
                text: "Move to Inbox"
                iconText: "\uf01c"
                iconFontFamily: "JetBrainsMono Nerd Font"
                onClicked: pane.moveToInboxRequested()
            }

            Astrea.Button {
                text: "Trash"
                iconText: "\uf1f8"
                iconFontFamily: "JetBrainsMono Nerd Font"
                danger: true
                enabled: pane.message.folder !== "Trash"
                onClicked: pane.trashRequested()
            }

            Astrea.Button {
                visible: pane.hasRemoteImages()
                text: "Load images"
                iconText: "\uf03e"
                iconFontFamily: "JetBrainsMono Nerd Font"
                flat: true
                onClicked: pane.loadImagesRequested()
            }

            Item { Layout.fillWidth: true }

            TagPill {
                label: pane.message.importance === "high" ? "Important" : pane.message.tag || "Mail"
                tag: pane.message.importance === "high" ? "Important" : pane.message.tag || ""
            }
        }

        Astrea.Divider {
            lineColor: Astrea.Theme.cardBorder
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Astrea.Theme.controlRadius + 4
            color: pane.softSurface
            border.width: 1
            border.color: Astrea.Theme.cardBorder
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: Astrea.Theme.spacingLarge
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.availableWidth
                    spacing: Astrea.Theme.spacingLarge

                    Text {
                        Layout.fillWidth: true
                        text: pane.hasHtmlBody() ? pane.message.htmlBody : pane.message.body || ""
                        textFormat: pane.hasHtmlBody() ? Text.RichText : Text.PlainText
                        color: Astrea.Theme.textPrimary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeLarge
                        lineHeight: 1.28
                        wrapMode: Text.WordWrap
                        horizontalAlignment: pane.message.htmlRenderMode === "reader" ? Text.AlignLeft : (pane.hasHtmlBody() ? Text.AlignHCenter : Text.AlignLeft)
                        linkColor: Astrea.Theme.accent
                        renderType: Text.NativeRendering
                        antialiasing: true
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }

                    Repeater {
                        model: pane.attachmentList()

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Astrea.Theme.spacingSmall

                            Rectangle {
                                Layout.fillWidth: true
                                visible: modelData.dataUrl !== ""
                                radius: Astrea.Theme.controlRadius + 2
                                color: Qt.rgba(Astrea.Theme.textPrimary.r, Astrea.Theme.textPrimary.g, Astrea.Theme.textPrimary.b, 0.04)
                                border.width: 1
                                border.color: Astrea.Theme.cardBorder
                                implicitHeight: attachmentImage.visible ? Math.min(Math.max(attachmentImage.implicitHeight, 180), 360) : 0
                                clip: true

                                Image {
                                    id: attachmentImage
                                    anchors.fill: parent
                                    anchors.margins: Astrea.Theme.spacingSmall
                                    visible: modelData.dataUrl !== ""
                                    source: modelData.dataUrl || ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    cache: true
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: Astrea.Theme.controlRadius
                                color: pane.softSurface
                                border.width: 1
                                border.color: Astrea.Theme.cardBorder
                                implicitHeight: 44

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Astrea.Theme.spacing
                                    anchors.rightMargin: Astrea.Theme.spacing
                                    spacing: Astrea.Theme.spacing

                                    Text {
                                        text: (modelData.mimeType || "").indexOf("image/") === 0 ? "\uf03e" : "\uf0c6"
                                        color: Astrea.Theme.textSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                    }

                                    Astrea.TextLabel {
                                        Layout.fillWidth: true
                                        text: modelData.name || "Attachment"
                                        textColor: Astrea.Theme.textPrimary
                                        font.pixelSize: Astrea.Theme.fontSizeNormal
                                        elide: Text.ElideRight
                                    }

                                    Astrea.TextLabel {
                                        text: pane.formatBytes(modelData.size || 0)
                                        textColor: Astrea.Theme.textTertiary
                                        font.pixelSize: Astrea.Theme.fontSizeSmall
                                        visible: (modelData.size || 0) > 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Astrea.Theme.spacing
        visible: !pane.hasMessage

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf0e0"
            color: Astrea.Theme.textTertiary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 34
        }

        Astrea.TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Select a message"
            textColor: Astrea.Theme.textSecondary
            font.pixelSize: Astrea.Theme.fontSizeLarge
        }
    }

    function initials(name) {
        const parts = (name || "Mail").replace(/^\s+|\s+$/g, "").split(/\s+/)
        const first = parts.length > 0 ? parts[0].charAt(0) : "M"
        const second = parts.length > 1 ? parts[parts.length - 1].charAt(0) : ""
        return (first + second).toUpperCase()
    }

    function attachmentList() {
        if (!pane.message || pane.message.attachments === undefined)
            return []
        const attachments = pane.message.attachments || []
        if (!pane.hasHtmlBody())
            return attachments

        const visibleAttachments = []
        for (let i = 0; i < attachments.length; i++) {
            const attachment = attachments[i]
            if (!attachment.inline || attachment.dataUrl === "")
                visibleAttachments.push(attachment)
        }
        return visibleAttachments
    }

    function hasHtmlBody() {
        return pane.message
            && pane.message.htmlBody !== undefined
            && String(pane.message.htmlBody || "").replace(/^\s+|\s+$/g, "") !== ""
    }

    function hasRemoteImages() {
        return pane.message
            && Number(pane.message.remoteImageCount || 0) > 0
            && !pane.message.remoteImagesLoaded
            && pane.message.htmlRenderMode !== "reader"
    }

    function formatBytes(value) {
        const size = Number(value || 0)
        if (size <= 0)
            return ""
        if (size < 1024)
            return size + " B"
        if (size < 1024 * 1024)
            return Math.round(size / 1024) + " KB"
        return (size / (1024 * 1024)).toFixed(size < 10 * 1024 * 1024 ? 1 : 0) + " MB"
    }
}
