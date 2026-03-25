//@ pragma UseQApplication
import Quickshell
import "./bar"
import "./island"
import "./spotlight" // O QML já vai buscar os arquivos com letra maiúscula aqui dentro
import "./notifications"

ShellRoot {
    id: root

    // Suas Bars
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Suas Islands
    Variants {
        model: Quickshell.screens
        delegate: Island {
            required property var modelData
            screen: modelData
        }
    }

    // O seu Spotlightzão centralizado
    Spotlight {
    }
}
