import QtQuick
import "../tokens"

/* Project Tahoe X86 in-shell window layer.
 *
 * Owns the windows of the applications this shell hosts. It is a real window manager for
 * those windows: it creates them, cascades their initial position, tracks stacking order,
 * focuses the top-most window, and minimises, restores, and closes them on request.
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
        "settings": "qrc:/apps/settings/SettingsWindow.qml"
    })

    readonly property var appTitles: ({
        "finder": qsTr("Finder"),
        "settings": qsTr("Settings")
    })

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
        var width = Math.min(860, parent ? parent.width - 80 : 860)
        var height = Math.min(580, parent ? parent.height - 140 : 580)

        windows.append({
            "appId": appId,
            "title": displayTitle(appId, fallbackTitle),
            "x": 48 + step * 28,
            "y": 32 + step * 28,
            "width": Math.max(420, width),
            "height": Math.max(280, height),
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

            // Initial geometry comes from the model once, then this frame owns it and
            // writes changes back. Binding instead would fight every drag.
            Component.onCompleted: {
                x = model.x
                y = model.y
                width = model.width
                height = model.height
            }

            function syncGeometry() {
                var row = layer.rowFor(appId)
                if (row < 0)
                    return
                layer.windows.setProperty(row, "x", x)
                layer.windows.setProperty(row, "y", y)
                layer.windows.setProperty(row, "width", width)
                layer.windows.setProperty(row, "height", height)
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
