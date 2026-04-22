//@ pragma UseQApplication
//@ pragma IconTheme WhiteSur-dark
import Quickshell
import "./bar"
import "./island"
import "./spotlight"

ShellRoot {
    id: root

    MusicMonitor {
        id: musicMonitor
    }

    // Bar — one per screen
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Island {
            required property var modelData
            screen: modelData
            sharedMusicState: musicMonitor
        }
    }

    Spotlight {}
}
