import QtQuick
import Tahoe.Services 1.0
import "../tokens"

/* Project Tahoe X86 in-shell window layer.
 *
 * Owns the windows of the applications this shell hosts. It is a real window manager for
 * those windows: it creates them, cascades their initial position, tracks stacking order,
 * focuses the top-most window, and minimises, restores, and closes them on request.
 *
 * Geometry is remembered per application through the Settings model, so a hosted window
 * reopens where it was last moved and resized. Saved geometry is clamped to the current
 * layer size, so a window saved on a larger display is never placed off screen.
 *
 * Scope is stated honestly: only applications that ship as QML inside this shell are
 * managed here. Applications launched from the registry (Firefox, a terminal emulator, and
 * so on) are separate processes with compositor-managed windows, and the compositor owns
 * their geometry, stacking, and focus - not this layer.
 */
Item {
    id: layer

    // Applications this shell hosts, by application id.
    readonly property var appSources: ({
        "finder": "qrc:/apps/finder/FinderWindow.qml",
        "settings": "qrc:/apps/settings/SettingsWindow.qml",
        "calculator": "qrc:/apps/calculator/CalculatorWindow.qml"
    })

    readonly property var appTitles: ({
        "finder": qsTr("Finder"),
        "settings": qsTr("Settings"),
        "calculator": qsTr("Calculator")
    })

    // System icon names for the hosted applications. Names rather than paths: the shell
    // resolves them through the icon theme, the same way it resolves an installed
    // application's icon, and shows a label instead when nothing is found.
    readonly property var appIcons: ({
        "finder": "system-file-manager",
        "settings": "preferences-system",
        "calculator": "accessories-calculator"
    })

    // Smallest size a hosted window may be restored to, matching the resize handles.
    readonly property int minWindowWidth: 420
    readonly property int minWindowHeight: 280

    // Open windows. Row roles: appId, title, x, y, width, height, stack, minimized, zoomed.
    property ListModel windows: ListModel {}

    property int topStack: 1
    property string activeAppId: ""
    property bool reduceMotion: false
    property bool showTitleBars: true
    property int cornerRadius: DesignTokens.radiusDefault

    // Emitted when an application's QML cannot be loaded, so the shell can report it
    // instead of showing an empty frame.
    property string lastLoadError: ""

    signal windowOpened(string appId)
    signal windowClosed(string appId)
    signal loadFailed(string appId, string message)

    function sourceFor(appId) {
        return appSources[appId] !== undefined ? appSources[appId] : ""
    }

    function displayTitle(appId, fallback) {
        if (appTitles[appId] !== undefined)
            return appTitles[appId]
        return fallback && fallback.length > 0 ? fallback : appId
    }

    // Icon theme name for a hosted application, or empty when it has none.
    function iconNameFor(appId) {
        return appIcons[appId] !== undefined ? appIcons[appId] : ""
    }

    function hostedAppIds() {
        var ids = []
        for (var key in appSources)
            ids.push(key)
        return ids
    }

    function isHosted(appId) {
        return appSources[appId] !== undefined
    }

    function rowFor(appId) {
        for (var row = 0; row < windows.count; ++row) {
            if (windows.get(row).appId === appId)
                return row
        }
        return -1
    }

    function isOpen(appId) {
        return rowFor(appId) >= 0
    }

    function isMinimized(appId) {
        var row = rowFor(appId)
        return row >= 0 ? windows.get(row).minimized : false
    }

    function clampNumber(value, low, high) {
        return Math.max(low, Math.min(high, value))
    }

    // Placement for a newly opened window: its last saved geometry when there is one that
    // still fits, otherwise the cascade position and default size.
    function placementFor(appId, cascadeStep, defaultWidth, defaultHeight) {
        var areaWidth = parent ? parent.width : defaultWidth
        var areaHeight = parent ? parent.height : defaultHeight
        var saved = Settings.geometryFor(appId)

        if (saved && typeof saved.width === "number" && typeof saved.height === "number"
                && typeof saved.x === "number" && typeof saved.y === "number") {
            var width = clampNumber(saved.width, minWindowWidth, Math.max(minWindowWidth, areaWidth))
            var height = clampNumber(saved.height, minWindowHeight, Math.max(minWindowHeight, areaHeight))
            return {
                "x": clampNumber(saved.x, 0, Math.max(0, areaWidth - 120)),
                "y": clampNumber(saved.y, 0, Math.max(0, areaHeight - 40)),
                "width": width,
                "height": height
            }
        }

        return {
            "x": 48 + cascadeStep * 28,
            "y": 32 + cascadeStep * 28,
            "width": Math.max(minWindowWidth, defaultWidth),
            "height": Math.max(minWindowHeight, defaultHeight)
        }
    }

    function openWindow(appId, fallbackTitle) {
        if (!isHosted(appId)) {
            lastLoadError = qsTr("'%1' is not an application this shell hosts").arg(appId)
            loadFailed(appId, lastLoadError)
            return false
        }

        var existing = rowFor(appId)
        if (existing >= 0) {
            // Already open: bring it forward rather than opening a second copy.
            windows.setProperty(existing, "minimized", false)
            raiseWindow(appId)
            return true
        }

        // Cascade placement so successive windows do not stack exactly on top of each other.
        var step = windows.count % 6
        var defaultWidth = Math.min(860, parent ? parent.width - 80 : 860)
        var defaultHeight = Math.min(580, parent ? parent.height - 140 : 580)
        var placement = placementFor(appId, step, defaultWidth, defaultHeight)

        windows.append({
            "appId": appId,
            "title": displayTitle(appId, fallbackTitle),
            "x": placement.x,
            "y": placement.y,
            "width": placement.width,
            "height": placement.height,
            "stack": ++topStack,
            "minimized": false,
            "zoomed": false
        })

        activeAppId = appId
        windowOpened(appId)
        return true
    }

    function closeWindow(appId) {
        var row = rowFor(appId)
        if (row < 0)
            return

        windows.remove(row)
        if (activeAppId === appId)
            activeAppId = topVisibleAppId()
        windowClosed(appId)
    }

    function minimizeWindow(appId) {
        var row = rowFor(appId)
        if (row < 0)
            return

        windows.setProperty(row, "minimized", true)
        activeAppId = topVisibleAppId()
    }

    function restoreWindow(appId) {
        var row = rowFor(appId)
        if (row < 0)
            return

        windows.setProperty(row, "minimized", false)
        raiseWindow(appId)
    }

    function raiseWindow(appId) {
        var row = rowFor(appId)
        if (row < 0)
            return

        windows.setProperty(row, "stack", ++topStack)
        windows.setProperty(row, "minimized", false)
        activeAppId = appId
    }

    function toggleWindow(appId, fallbackTitle) {
        var row = rowFor(appId)
        if (row < 0) {
            openWindow(appId, fallbackTitle)
            return
        }

        // Clicking a Dock icon for a visible, focused window minimises it, matching the
        // behaviour people expect from a Dock.
        if (activeAppId === appId && !isMinimized(appId))
            minimizeWindow(appId)
        else
            raiseWindow(appId)
    }

    function topVisibleAppId() {
        var bestRow = -1
        var bestStack = -1

        for (var row = 0; row < windows.count; ++row) {
            var entry = windows.get(row)
            if (entry.minimized)
                continue
            if (entry.stack > bestStack) {
                bestStack = entry.stack
                bestRow = row
            }
        }

        return bestRow >= 0 ? windows.get(bestRow).appId : ""
    }

    Repeater {
        model: layer.windows

        delegate: TahoeWindow {
            id: frame

            appId: model.appId
            title: model.title
            isMinimized: model.minimized
            isZoomed: model.zoomed
            isActive: model.stack === layer.topStack
            reduceMotion: layer.reduceMotion
            showTitleBar: layer.showTitleBars
            cornerRadius: layer.cornerRadius
            // The layer draws above the Dock area only where a window actually sits.
            z: 10 + model.stack

            // Set once the initial geometry has been applied. Until then, geometry changes are
            // the layer placing the window, not the user, so they are not written to settings.
            property bool geometryReady: false

            // Initial geometry comes from the model once, then this frame owns it and
            // writes changes back. Binding instead would fight every drag.
            Component.onCompleted: {
                x = model.x
                y = model.y
                width = model.width
                height = model.height
                geometryReady = true
            }

            // Remember the window's place for the next time it is opened. Zoomed geometry is
            // the screen-filling state, so it is never saved as the normal size.
            function persistGeometry() {
                if (!geometryReady || frame.isZoomed)
                    return
                Settings.setWindowGeometry(appId, { "x": x, "y": y, "width": width, "height": height })
            }

            function syncGeometry() {
                var row = layer.rowFor(appId)
                if (row < 0)
                    return
                layer.windows.setProperty(row, "x", x)
                layer.windows.setProperty(row, "y", y)
                layer.windows.setProperty(row, "width", width)
                layer.windows.setProperty(row, "height", height)
                persistGeometry()
            }

            onXChanged: syncGeometry()
            onYChanged: syncGeometry()
            onWidthChanged: syncGeometry()
            onHeightChanged: syncGeometry()

            onFocusRequested: layer.raiseWindow(appId)

            onCloseRequested: layer.closeWindow(appId)
            onMinimizeRequested: layer.minimizeWindow(appId)
            onZoomRequested: {
                var row = layer.rowFor(appId)
                if (row < 0)
                    return
                if (frame.isZoomed) {
                    restoreFromZoom()
                    layer.windows.setProperty(row, "zoomed", false)
                    // Geometry changed while still zoomed, so it was not saved then. Save now.
                    persistGeometry()
                } else {
                    zoomToFill()
                    layer.windows.setProperty(row, "zoomed", true)
                }
            }

            Loader {
                id: contentLoader
                anchors.fill: parent
                source: layer.sourceFor(frame.appId)

                onLoaded: {
                    if (!item)
                        return
                    // Applications receive their frame so they can close or minimise
                    // themselves, and so they can read the active appearance.
                    item.windowFrame = frame
                    item.reduceMotion = Qt.binding(function () { return layer.reduceMotion })
                }

                onStatusChanged: {
                    if (status === Loader.Error) {
                        layer.lastLoadError = qsTr("Could not load %1: %2")
                            .arg(frame.appId)
                            .arg(source)
                        layer.loadFailed(frame.appId, layer.lastLoadError)
                    }
                }
            }
        }
    }
}
