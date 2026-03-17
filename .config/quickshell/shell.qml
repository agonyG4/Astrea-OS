//@ pragma UseQApplication
import Quickshell
import "./bar"
import "./island"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Island {
            required property var modelData
            screen: modelData
        }
    }
}