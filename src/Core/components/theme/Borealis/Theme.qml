import QtQuick
import "." as Borealis

Item {
    id: theme
    visible: false
    width: 0
    height: 0

    readonly property string configPath: Borealis.State.configPath
    readonly property string colorSchemeApplyPath: Borealis.State.colorSchemeApplyPath
    readonly property string decorationApplyPath: Borealis.State.decorationApplyPath
    property bool loaded: Borealis.State.loaded

    property int themeMode: Borealis.State.themeMode
    property int shellStyle: Borealis.State.shellStyle
    property int iconStyle: Borealis.State.iconStyle
    property string iconTheme: Borealis.State.iconTheme
    property string accentHex: Borealis.State.accentHex
    property int audioOsdStyle: Borealis.State.audioOsdStyle
    property int persistedShellStyle: Borealis.State.persistedShellStyle

    onLoadedChanged: if (Borealis.State.loaded !== loaded) Borealis.State.loaded = loaded
    onThemeModeChanged: if (Borealis.State.themeMode !== themeMode) Borealis.State.themeMode = themeMode
    onShellStyleChanged: if (Borealis.State.shellStyle !== shellStyle) Borealis.State.shellStyle = shellStyle
    onIconStyleChanged: if (Borealis.State.iconStyle !== iconStyle) Borealis.State.iconStyle = iconStyle
    onIconThemeChanged: if (Borealis.State.iconTheme !== iconTheme) Borealis.State.iconTheme = iconTheme
    onAccentHexChanged: if (Borealis.State.accentHex !== accentHex) Borealis.State.accentHex = accentHex
    onAudioOsdStyleChanged: if (Borealis.State.audioOsdStyle !== audioOsdStyle) Borealis.State.audioOsdStyle = audioOsdStyle
    onPersistedShellStyleChanged: if (Borealis.State.persistedShellStyle !== persistedShellStyle) Borealis.State.persistedShellStyle = persistedShellStyle

    Connections {
        target: Borealis.State
        function onLoadedChanged() { if (theme.loaded !== Borealis.State.loaded) theme.loaded = Borealis.State.loaded }
        function onThemeModeChanged() { if (theme.themeMode !== Borealis.State.themeMode) theme.themeMode = Borealis.State.themeMode }
        function onShellStyleChanged() { if (theme.shellStyle !== Borealis.State.shellStyle) theme.shellStyle = Borealis.State.shellStyle }
        function onIconStyleChanged() { if (theme.iconStyle !== Borealis.State.iconStyle) theme.iconStyle = Borealis.State.iconStyle }
        function onIconThemeChanged() { if (theme.iconTheme !== Borealis.State.iconTheme) theme.iconTheme = Borealis.State.iconTheme }
        function onAccentHexChanged() { if (theme.accentHex !== Borealis.State.accentHex) theme.accentHex = Borealis.State.accentHex }
        function onAudioOsdStyleChanged() { if (theme.audioOsdStyle !== Borealis.State.audioOsdStyle) theme.audioOsdStyle = Borealis.State.audioOsdStyle }
        function onPersistedShellStyleChanged() { if (theme.persistedShellStyle !== Borealis.State.persistedShellStyle) theme.persistedShellStyle = Borealis.State.persistedShellStyle }
    }

    function applyConfig(cfg) {
        Borealis.State.applyConfig(cfg)
    }

    function save() {
        Borealis.State.save()
    }

    readonly property string fontFamily: Borealis.Tokens.fontFamily
    readonly property string monoFontFamily: Borealis.Tokens.monoFontFamily

    readonly property int fontSizeHero: Borealis.Tokens.fontSizeHero
    readonly property int fontSizeHeader: Borealis.Tokens.fontSizeHeader
    readonly property int fontSizeIconLarge: Borealis.Tokens.fontSizeIconLarge
    readonly property int fontSizeAvatar: Borealis.Tokens.fontSizeAvatar
    readonly property int fontSizeSubtitle: Borealis.Tokens.fontSizeSubtitle
    readonly property int fontSizeTitle: Borealis.Tokens.fontSizeTitle
    readonly property int fontSizeLarge: Borealis.Tokens.fontSizeLarge
    readonly property int fontSizeNormal: Borealis.Tokens.fontSizeNormal
    readonly property int fontSizeSmall: Borealis.Tokens.fontSizeSmall
    readonly property int fontSizeTiny: Borealis.Tokens.fontSizeTiny
    readonly property int fontSizeMicro: Borealis.Tokens.fontSizeMicro

    readonly property int fontWeightLight: Borealis.Tokens.fontWeightLight
    readonly property int fontWeightNormal: Borealis.Tokens.fontWeightNormal
    readonly property int fontWeightMedium: Borealis.Tokens.fontWeightMedium
    readonly property int fontWeightDemiBold: Borealis.Tokens.fontWeightDemiBold
    readonly property int fontWeightBold: Borealis.Tokens.fontWeightBold

    readonly property real trackingHeader: Borealis.Tokens.trackingHeader

    readonly property real radiusSmall: Borealis.Tokens.radiusSmall
    readonly property real radiusMedium: Borealis.Tokens.radiusMedium
    readonly property real radiusLarge: Borealis.Tokens.radiusLarge
    readonly property real cornerRadiusSmall: Borealis.Tokens.cornerRadiusSmall
    readonly property real cornerRadius: Borealis.Tokens.cornerRadius
    readonly property real cornerRadiusLarge: Borealis.Tokens.cornerRadiusLarge
    readonly property real cardRadius: Borealis.Tokens.cardRadius
    readonly property real controlRadius: Borealis.Tokens.controlRadius

    readonly property real spacingTiny: Borealis.Tokens.spacingTiny
    readonly property real spacingMicro: Borealis.Tokens.spacingMicro
    readonly property real spacingSmall: Borealis.Tokens.spacingSmall
    readonly property real spacing: Borealis.Tokens.spacing
    readonly property real spacingMedium: Borealis.Tokens.spacingMedium
    readonly property real spacingLarge: Borealis.Tokens.spacingLarge
    readonly property real spacingXLarge: Borealis.Tokens.spacingXLarge
    readonly property real pageMargin: Borealis.Tokens.pageMargin

    readonly property int animationMicro: Borealis.Tokens.animationMicro
    readonly property int animationQuick: Borealis.Tokens.animationQuick
    readonly property int animationFast: Borealis.Tokens.animationFast
    readonly property int animationNormal: Borealis.Tokens.animationNormal
    readonly property int animationSlow: Borealis.Tokens.animationSlow
    readonly property int animationPopover: Borealis.Tokens.animationPopover

    readonly property real opacityDisabled: Borealis.Tokens.opacityDisabled
    readonly property real opacitySecondary: Borealis.Tokens.opacitySecondary
    readonly property real opacityMuted: Borealis.Tokens.opacityMuted

    readonly property color accent: Borealis.Apps.accent
    readonly property color accentForeground: Borealis.Apps.accentForeground
    readonly property color textPrimary: Borealis.Apps.textPrimary
    readonly property color textSecondary: Borealis.Apps.textSecondary
    readonly property color textTertiary: Borealis.Apps.textTertiary
    readonly property color cardBg: Borealis.Apps.cardBg
    readonly property color cardBorder: Borealis.Apps.cardBorder
    readonly property color popupBg: Borealis.Apps.popupBg
    readonly property color windowBackground: Borealis.Apps.windowBackground
    readonly property color windowBorder: Borealis.Apps.windowBorder
    readonly property color windowWash: Borealis.Apps.windowWash
    readonly property color errorColor: Borealis.Apps.errorColor
    readonly property color warningColor: Borealis.Apps.warningColor
    readonly property color successColor: Borealis.Apps.successColor

    readonly property bool isLight: Borealis.Shell.isLight
    readonly property bool isTransparent: Borealis.Shell.isTransparent
    readonly property bool isDefault: Borealis.Shell.isDefault
    readonly property bool isFrosted: Borealis.Shell.isFrosted
    readonly property color shellBackground: Borealis.Shell.background
    readonly property color shellSurface: Borealis.Shell.surface
    readonly property color shellBorder: Borealis.Shell.border
    readonly property color shellBarBorderHover: Borealis.Shell.barBorderHover
    readonly property color shellSeparatorToken: Borealis.Shell.separator
    readonly property color shellHover: Borealis.Shell.hover
    readonly property color shellPressed: Borealis.Shell.pressed
    readonly property color shellActive: Borealis.Shell.active
    readonly property color islandBackground: Borealis.Shell.islandBackground
    readonly property color shellTextMain: Borealis.Shell.textMain
    readonly property color shellTextSecondary: Borealis.Shell.textSecondary
    readonly property color shellTextLight: Borealis.Shell.textLight
    readonly property color shellTextDim: Borealis.Shell.textDim
    readonly property color shellTextActive: Borealis.Shell.textActive
    readonly property color shellIconMain: Borealis.Shell.iconMain
    readonly property color shellIconActive: Borealis.Shell.iconActive
    readonly property color shellIconMuted: Borealis.Shell.iconMuted
    readonly property color shellIconWarning: Borealis.Shell.iconWarning
    readonly property color shellIconAccent: Borealis.Shell.iconAccent
    readonly property real shellRadiusLarge: Borealis.Shell.radiusLarge
    readonly property real shellRadiusMedium: Borealis.Shell.radiusMedium
    readonly property real shellRadiusSmall: Borealis.Shell.radiusSmall
    readonly property real shellControlRadius: Borealis.Shell.controlRadius
    readonly property real shellTileRadius: Borealis.Shell.tileRadius
    readonly property real shellPillRadius: Borealis.Shell.pillRadius
    readonly property int shellWorkspaceDotSize: Borealis.Shell.workspaceDotSize
    readonly property int shellWorkspaceActiveWidth: Borealis.Shell.workspaceActiveWidth

    readonly property var apps: Borealis.Apps
    readonly property var shell: Borealis.Shell
    readonly property var tokens: Borealis.Tokens
    readonly property var state: Borealis.State
}
