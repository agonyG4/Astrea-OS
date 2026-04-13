import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    property real contentMargins: 28
    property real maxWidth:       800  // Maximum width for the content area
    
    // Default property allows placing items directly inside ScrollPage
    default property alias content: contentColumn.data
    
    contentWidth: availableWidth
    ScrollBar.vertical.policy: ScrollBar.AsNeeded
    
    // We use a custom scrollbar style to make it look premium (optional, but good)
    // For now, we'll keep the default or slightly customize it.
    
    ColumnLayout {
        id: contentColumn
        // Width will be at most maxWidth, but not larger than parent.
        width: Math.min(root.width - (root.contentMargins * 2), root.maxWidth)
        anchors.horizontalCenter: parent.horizontalCenter
        
        spacing: 0
        
        // Add top and bottom margins via padding/spacing
        Item { Layout.preferredHeight: root.contentMargins }
        
        // Content items will be added here via contentData
        
        Item { Layout.preferredHeight: root.contentMargins + 12 } // Extra bottom space
    }
}
