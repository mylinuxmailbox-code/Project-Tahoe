pragma Singleton
import QtQuick

/* Project Tahoe X86 design tokens.
 *
 * Single source of truth for shell colors, spacing, radii, sizes, and animation values.
 * Consumers import this module and reference DesignTokens.<token>, which keeps them
 * reactive: switching `mode` re-colors every bound surface at once.
 *
 * Light/dark palettes are both defined here. Only the tokens below are authoritative;
 * components must not hardcode colors of their own.
 */
QtObject {
    id: tokens

    // "dark" (default) or "light". Drive this from the appearance setting.
    property string mode: "dark"
    readonly property bool isDark: mode !== "light"

    // ---- Surfaces ----
    property color bgBase: isDark ? "#0f1113" : "#eceef1"
    property color bgPanel: isDark ? "#0b0d0f" : "#f7f8fa"
    property color bgRaised: isDark ? "#1c1f24" : "#ffffff"
    property color borderDefault: isDark ? "#2a2e34" : "#d3d7de"

    // ---- Text ----
    property color textPrimary: isDark ? "#e6e8eb" : "#1b1d21"
    property color textSecondary: isDark ? "#d6dae0" : "#3a3f47"
    property color textMuted: isDark ? "#9aa0a8" : "#6b7280"
    property color accent: "#3994ff"

    // ---- State colors ----
    property color statusOk: "#3fb950"
    property color statusWarning: "#d29922"
    property color statusError: "#f85149"

    // ---- Radii ----
    property int radiusSmall: 8
    property int radiusDefault: 12
    property int radiusPanel: 16
    property int radiusMenu: 10

    // ---- Spacing ----
    property int spacingTiny: 4
    property int spacingSmall: 8
    property int spacingDefault: 14
    property int spacingLarge: 24

    // ---- Typography ----
    property int fontSizeCaption: 11
    property int fontSizeBody: 13
    property int fontSizePanel: 13
    property int fontSizeTitle: 15

    // ---- Chrome and icon sizing ----
    property int menuBarHeight: 44
    property int dockHeight: 64
    property int iconSizeSmall: 28
    property int iconSizeDefault: 48
    property int iconSizeLarge: 64

    // ---- Motion ----
    property real animationFast: 120
    property real animationNormal: 220
    property real animationSlow: 360

    // ---- Derived translucent surfaces ----
    property color bgGlass: Qt.rgba(bgPanel.r, bgPanel.g, bgPanel.b, isDark ? 0.92 : 0.94)
    property color borderGlass: borderDefault
}
