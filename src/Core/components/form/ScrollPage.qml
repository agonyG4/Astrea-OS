import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as Components

/**
 * ScrollPage - A standardized scrollable container for settings pages.
 * Ensures the scrollbar is at the far right edge of the window while 
 * maintaining centered content with proper margins.
 */
ScrollView {
    id: root
    anchors.fill: parent
    clip: true
    
    // Configurable properties
    property real contentMargins: Components.Theme.pageMargin
    property real maxWidth:       800  // Maximum width for the content area
    property real scrollGap:      14
    
    // Default property allows placing items directly inside ScrollPage
    default property alias content: contentColumn.data
    
    contentWidth: availableWidth
    ScrollBar.vertical: ScrollBar {
        parent: root
        anchors {
            top: root.top
            bottom: root.bottom
            right: root.right
            topMargin: root.contentMargins
            bottomMargin: root.contentMargins + 12
            rightMargin: 0
        }
        policy: ScrollBar.AsNeeded
    }
    
    // We use a custom scrollbar style to make it look premium (optional, but good)
    // For now, we'll keep the default or slightly customize it.
    
    ColumnLayout {
        id: contentColumn
        // Base width on availableWidth so the content yields space when the
        // vertical scrollbar becomes visible, keeping the indicator outside
        // the visual content block.
        width: Math.min(
            Math.max(0, root.availableWidth - (root.contentMargins * 2) - root.scrollGap),
            root.maxWidth
        )
        anchors.horizontalCenter: parent.horizontalCenter
        
        spacing: 0
        
        // Add top and bottom margins via padding/spacing
        Item { Layout.preferredHeight: root.contentMargins }
        
        // Content items will be added here via contentData
        
        Item { Layout.preferredHeight: root.contentMargins + 12 } // Extra bottom space
    }
}
