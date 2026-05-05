//@ pragma UseQApplication
import Quickshell
import "./island"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        delegate: Island {
            required property var modelData
            screen: modelData
        }
    }
}
