pragma Singleton
import QtQuick 2.15

QtObject {
    // Cores de Fundo
    readonly property color bg: "#1C1C1E"
    readonly property color cardBg: "#2F2F34"
    readonly property real cardOpacity: 0.92
    
    // Cores de Texto
    readonly property color textPrimary: "#F5F5F7"
    readonly property color textSecondary: "#D7D7DD"
    readonly property color textTertiary: "#B9B9C2"
    readonly property color textDisabled: "#94949D"
    
    // Cores de Ícones e Destaques
    readonly property color accent: "#007AFF"
    readonly property color rain: "#9CC7FF"
    readonly property color sun: "#F5D44A"
    
    // Tamanhos de Fonte Padrão
    readonly property int fontTiny: 9
    readonly property int fontSmall: 11
    readonly property int fontRegular: 13
    readonly property int fontMedium: 15
    readonly property int fontLarge: 22
    readonly property int fontXLarge: 34
    readonly property int fontGiant: 92
    
    // Outras Medidas
    readonly property int cardRadius: 18
}
