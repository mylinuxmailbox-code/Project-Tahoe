pragma Singleton
import QtQuick

/* Project Tahoe X86 settings model (singleton).
 *
 * One instance is shared by the shell and by the applications it hosts, so a change made in
 * the Settings application is immediately visible in the Dock, the desktop, and the window
 * layer - and is written to disk once.
 *
 * File I/O is NOT done here: it belongs to the SettingsStore C++ service
 * (src/services/SettingsStore.h), which owns
 * $XDG_CONFIG_HOME/project-tahoe/shell/settings.json.
 *
 * Failure policy: applyConfig() only accepts keys it recognises, so an unknown or partially
 * corrupt file can never put the shell into an undefined state. When the store reports
 * defaults, these values are used unchanged.
 *
 * Persistence signal: persistedValueChanged() is emitted whenever a value that is written to
 * disk changes. The shell debounces that into a single file write. Applying a loaded config
 * suppresses the signal so a load never triggers a redundant save.
 *
 * Secrets are never stored here. Credentials belong in the Secret Service keyring.
 */
QtObject {
    id: settings

    // Emitted when any value that lives in settings.json changes.
    signal persistedValueChanged()

    // True only while applyConfig() is assigning, so loading does not mark the config dirty.
    property bool suppressChangeNotifications: false

    // Transient navigation request, set by the shell when a Spotlight result names a setting.
    // It is deliberately NOT part of collectConfig(), so it is never written to disk.
    property string requestedSection: ""

    // ---- Dock ----
    property string dockPosition: "bottom"
    property int dockIconSize: 48
    property bool dockMagnification: true
    property real dockMagnificationStrength: 0.3
    property bool dockAutoHide: false
    property var dockPinnedApps: [
        { "id": "finder", "label": "Finder" },
        { "id": "settings", "label": "Settings" }
    ]

    // ---- Appearance ----
    property string appearanceMode: "dark"
    property bool reduceMotion: false

    // ---- Desktop ----
    property string wallpaperSource: ""

    // ---- Window chrome ----
    property bool showWindowTitleBars: true
    property int windowCornerRadius: 12

    // ---- Hosted window geometry ----
    // Map of hosted application id to { "x", "y", "width", "height" }. Written when a window
    // is moved or resized, and read back when the window is opened again. Never assigned in
    // place: setWindowGeometry() replaces the whole map, so every change is observed.
    property var windowGeometry: ({})

    onDockPositionChanged: notify()
    onDockIconSizeChanged: notify()
    onDockMagnificationChanged: notify()
    onDockMagnificationStrengthChanged: notify()
    onDockAutoHideChanged: notify()
    onDockPinnedAppsChanged: notify()
    onAppearanceModeChanged: notify()
    onReduceMotionChanged: notify()
    onWallpaperSourceChanged: notify()
    onShowWindowTitleBarsChanged: notify()
    onWindowCornerRadiusChanged: notify()
    onWindowGeometryChanged: notify()

    function notify() {
        if (!suppressChangeNotifications)
            persistedValueChanged()
    }

    // Saved geometry for one hosted application, or null when none has been saved.
    function geometryFor(appId) {
        var saved = windowGeometry[appId]
        return saved !== undefined && saved !== null ? saved : null
    }

    // Record the geometry of one hosted application. Values are rounded so sub-pixel drags
    // do not produce a new file write on every frame.
    function setWindowGeometry(appId, rect) {
        var next = Object.assign({}, windowGeometry)
        next[appId] = {
            "x": Math.round(rect.x),
            "y": Math.round(rect.y),
            "width": Math.round(rect.width),
            "height": Math.round(rect.height)
        }
        windowGeometry = next
    }

    // The persisted JSON shape.
    function collectConfig() {
        return {
            "dockPosition": dockPosition,
            "dockIconSize": dockIconSize,
            "dockMagnification": dockMagnification,
            "dockMagnificationStrength": dockMagnificationStrength,
            "dockAutoHide": dockAutoHide,
            "dockPinnedApps": dockPinnedApps,
            "appearanceMode": appearanceMode,
            "reduceMotion": reduceMotion,
            "wallpaperSource": wallpaperSource,
            "showWindowTitleBars": showWindowTitleBars,
            "windowCornerRadius": windowCornerRadius,
            "windowGeometry": windowGeometry
        }
    }

    // Apply a loaded object. Unknown keys are ignored; missing keys keep their defaults.
    function applyConfig(values) {
        if (!values)
            return

        suppressChangeNotifications = true

        if ("dockPosition" in values)
            dockPosition = String(values.dockPosition)
        if ("dockIconSize" in values)
            dockIconSize = Number(values.dockIconSize)
        if ("dockMagnification" in values)
            dockMagnification = Boolean(values.dockMagnification)
        if ("dockMagnificationStrength" in values)
            dockMagnificationStrength = Number(values.dockMagnificationStrength)
        if ("dockAutoHide" in values)
            dockAutoHide = Boolean(values.dockAutoHide)
        if ("dockPinnedApps" in values && Array.isArray(values.dockPinnedApps) && values.dockPinnedApps.length > 0)
            dockPinnedApps = values.dockPinnedApps
        if ("appearanceMode" in values && (values.appearanceMode === "dark" || values.appearanceMode === "light"))
            appearanceMode = String(values.appearanceMode)
        if ("reduceMotion" in values)
            reduceMotion = Boolean(values.reduceMotion)
        if ("wallpaperSource" in values)
            wallpaperSource = String(values.wallpaperSource)
        if ("showWindowTitleBars" in values)
            showWindowTitleBars = Boolean(values.showWindowTitleBars)
        if ("windowCornerRadius" in values)
            windowCornerRadius = Number(values.windowCornerRadius)
        if ("windowGeometry" in values && values.windowGeometry && typeof values.windowGeometry === "object")
            windowGeometry = values.windowGeometry

        suppressChangeNotifications = false
    }
}
