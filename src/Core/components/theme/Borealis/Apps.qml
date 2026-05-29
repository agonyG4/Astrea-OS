pragma Singleton
import QtQuick
import "." as Borealis

QtObject {
    readonly property color accent: Borealis.State.accentHex
    readonly property color accentForeground: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.62
        ? "#111111"
        : "#ffffff"
    readonly property color textPrimary: Borealis.State.themeMode === 1 ? Qt.rgba(0.05, 0.06, 0.07, 0.94) : Qt.rgba(0.96, 0.96, 0.98, 0.94)
    readonly property color textSecondary: Borealis.State.themeMode === 1 ? Qt.rgba(0.13, 0.15, 0.18, 0.76) : Qt.rgba(0.92, 0.94, 0.96, 0.72)
    readonly property color textTertiary: Borealis.State.themeMode === 1 ? Qt.rgba(0.13, 0.15, 0.18, 0.50) : Qt.rgba(0.92, 0.94, 0.96, 0.48)
    readonly property color cardBg: {
        if (Borealis.State.shellStyle === 0)
            return Borealis.State.themeMode === 1 ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.035)
        if (Borealis.State.shellStyle === 2)
            return Borealis.State.themeMode === 1 ? Qt.rgba(0.98, 0.99, 1, 0.36) : Qt.rgba(1, 1, 1, 0.035)
        return Borealis.State.themeMode === 1 ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(1, 1, 1, 0.05)
    }
    readonly property color cardBorder: {
        if (Borealis.State.shellStyle === 0)
            return Borealis.State.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)
        if (Borealis.State.shellStyle === 2)
            return Borealis.State.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.06)
        return Borealis.State.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    }
    readonly property color popupBg: {
        if (Borealis.State.shellStyle === 0 || Borealis.State.shellStyle === 2)
            return Borealis.State.themeMode === 1 ? Qt.rgba(0.98, 0.98, 0.99, 0.92) : Qt.rgba(0.11, 0.11, 0.12, 0.92)
        return Borealis.State.themeMode === 1 ? Qt.rgba(0.98, 0.98, 0.99, 1) : Qt.rgba(0.11, 0.11, 0.12, 1)
    }
    readonly property color windowBackground: {
        if (Borealis.State.shellStyle === 0)
            return Borealis.State.themeMode === 1 ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.06)
        if (Borealis.State.shellStyle === 2)
            return Borealis.State.themeMode === 1 ? Qt.rgba(0.96, 0.985, 1, 0.24) : Qt.rgba(0, 0, 0, 0.06)
        return Borealis.State.themeMode === 1 ? Qt.rgba(0.965, 0.968, 0.98, 1.0) : Qt.rgba(0.11, 0.11, 0.12, 1.0)
    }
    readonly property color windowBorder: {
        if (Borealis.State.shellStyle === 0)
            return Borealis.State.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)
        if (Borealis.State.shellStyle === 2)
            return Borealis.State.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.06)
        return Borealis.State.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    }
    readonly property color windowWash: {
        if (Borealis.State.shellStyle === 0)
            return Borealis.State.themeMode === 1 ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        if (Borealis.State.shellStyle === 2)
            return Borealis.State.themeMode === 1 ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
        return Borealis.State.themeMode === 1 ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.02)
    }

    readonly property color errorColor: "#ff453a"
    readonly property color warningColor: "#ff9f0a"
    readonly property color successColor: "#30d158"
}
