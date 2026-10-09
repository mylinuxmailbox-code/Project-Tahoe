import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Tahoe.Services 1.0
import "../../shared/tokens"
import "../../shared/components"
import "../../services"

/* Project Tahoe X86 shell window.
 *
 * This is the shell's single surface: it hosts the desktop, the window layer, the Dock, the
 * menu bar, and the panels. Everything it draws is bound to a real service:
 *
 *   SettingsStore      persisted preferences        ($XDG_CONFIG_HOME/project-tahoe/shell)
 *   AppRegistry        installed applications       (.desktop entries on this machine)
 *   FileService        filesystem access            (Finder, trash counts)
 *   TrashService       freedesktop trash            (delete and restore)
 *   NotificationService notification list and the session notification server
 *   SearchService      Spotlight results            (apps, files, settings)
 *
 * Settings is a QML singleton in the services module, not a C++ service, because the shell
 * and the applications it hosts must read and write the same instance.
 *
 * The relative imports resolve against the shared module directories both from the source
 * tree and from the bundled resource tree, because src/shell/tahoe.qrc mirrors the source
 * layout:
 *
 *   on disk:  src/shell/qml/main.qml  ->  ../../shared/tokens  ->  src/shared/tokens
 *   in qrc:   /shell/qml/main.qml     ->  ../../shared/tokens  ->  /shared/tokens
 */
ApplicationWindow {
    id: root
    width: 1280
    height: 800
    visible: true
    title: "Project Tahoe X86"

    // Last result of a user-visible action, shown in the menu bar instead of being hidden in
    // a console log. Empty means nothing to report.
    property string statusMessage: ""
    property color statusColor: DesignTokens.textMuted

    function report(message, isError) {
        statusMessage = message
        statusColor = isError ? DesignTokens.statusError : DesignTokens.textMuted
    }

    // ------------------------------------------------ launching

    // Name of an installed application, for messages. Falls back to the id.
    function appName(desktopId) {
        var apps = AppRegistry.toVariantList()
        for (var i = 0; i < apps.length; ++i) {
            if (apps[i].desktopId === desktopId)
                return apps[i].name
        }
        return desktopId
    }

    // The single entry point for opening something by application id, used by the Dock and by
    // Spotlight so the two can never disagree about what happens.
    function activateApp(appId, label) {
        var name = label && label.length > 0 ? label : appName(appId)

        // 1. An application this shell hosts opens as a real window in the window layer.
        if (windowLayer.isHosted(appId)) {
            windowLayer.toggleWindow(appId, name)
            report(windowLayer.isMinimized(appId) ? qsTr("Minimised %1").arg(name)
                                                  : qsTr("Opened %1").arg(name), false)
            return
        }

        // 2. Anything else is launched as a real process through the registry.
        var result = AppRegistry.launchDesktopId(appId)
        if (result === AppRegistry.Started)
            report(qsTr("Opened %1").arg(name), false)
        else
            report(AppRegistry.lastError, true)
    }

    function openPath(path) {
        var result = AppRegistry.openPath(path)
        if (result !== AppRegistry.Started)
            report(AppRegistry.lastError, true)
        else
            report(qsTr("Opened %1").arg(path), false)
    }

    function showSetting(settingKey) {
        windowLayer.openWindow("settings", qsTr("Settings"))
        Settings.requestedSection = settingKey
        report(qsTr("Settings: %1").arg(settingKey), false)
    }

    function closePanels() {
        spotLight.close()
        controlCenter.close()
        notificationCenter.close()
    }

    // ------------------------------------------------ startup

    Component.onCompleted: {
        // Report the registry scan result: it is the difference between "no applications are
        // installed" and "the shell failed to find them".
        report(AppRegistry.status, false)

        if (!SettingsStore.available) {
            report("Settings: " + SettingsStore.status, true)
            return
        }

        Settings.applyConfig(SettingsStore.load())
        DesignTokens.mode = Settings.appearanceMode

        if (SettingsStore.status.indexOf("Defaults in use") === 0)
            report("Settings: " + SettingsStore.status, false)
    }

    // Debounced write: a burst of preference changes produces one file write.
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            if (!SettingsStore.available)
                return
            SettingsStore.save(Settings.collectConfig())
        }
    }

    Connections {
        target: Settings

        function onPersistedValueChanged() {
            DesignTokens.mode = Settings.appearanceMode
            saveTimer.restart()
        }
    }

    // ------------------------------------------------ keyboard shortcuts

    Shortcut {
        sequence: "Ctrl+Space"
        onActivated: {
            closePanels()
            spotLight.open()
        }
    }

    Shortcut {
        sequence: "Ctrl+,"
        onActivated: {
            closePanels()
            activateApp("settings", qsTr("Settings"))
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: closePanels()
    }

    // ------------------------------------------------ chrome

    header: TahoeMenuBar {
        activeAppName: windowLayer.activeAppId.length > 0
                       ? windowLayer.displayTitle(windowLayer.activeAppId, "")
                       : qsTr("Project Tahoe X86")
        statusMessage: root.statusMessage
        statusColor: root.statusColor
        unreadNotifications: NotificationService.unreadCount
        // Dimmed indicator when another daemon owns the notification name, so an empty list
        // is never mistaken for a quiet system.
        notificationServiceReady: NotificationService.dbusStatus.indexOf(
                                      "session notification server") >= 0

        onNotificationsRequested: {
            var wasOpen = notificationCenter.visible
            closePanels()
            if (!wasOpen)
                notificationCenter.open()
        }
        onControlCenterRequested: {
            var wasOpen = controlCenter.visible
            closePanels()
            if (!wasOpen)
                controlCenter.open()
        }
    }

    // Desktop surface, behind everything else.
    TahoeDesktop {
        id: desktop
        anchors.fill: parent
        z: 0
        wallpaperSource: Settings.wallpaperSource

        onWallpaperErrorChanged: {
            if (wallpaperError)
                root.report("Wallpaper could not be loaded: " + Settings.wallpaperSource, true)
        }
    }

    // Windows of the applications this shell hosts.
    TahoeWindowLayer {
        id: windowLayer
        anchors.fill: parent
        z: 100
        reduceMotion: Settings.reduceMotion
        showTitleBars: Settings.showWindowTitleBars
        cornerRadius: Settings.windowCornerRadius

        onLoadFailed: function (appId, message) {
            root.report(message, true)
        }
    }

    // The Dock is drawn above the windows so an auto-hidden Dock always reveals on top.
    TahoeDock {
        id: dock
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: DesignTokens.dockHeight
        z: 200

        iconSize: Settings.dockIconSize
        spacing: DesignTokens.spacingLarge
        magnification: Settings.dockMagnification
        magnificationStrength: Settings.dockMagnificationStrength
        autoHide: Settings.dockAutoHide
        reduceMotion: Settings.reduceMotion

        pinnedItems: Settings.dockPinnedApps
        // Running indicators come from the real open-window model.
        runningItems: root.runningItemList()

        onItemActivated: function (item) {
            root.activateApp(item.id, item.label)
        }
    }

    // Panels sit above everything, including the Dock.
    TahoeSpotlight {
        id: spotLight
        anchors.fill: parent
        z: 1000
        reduceMotion: Settings.reduceMotion

        onApplicationChosen: function (desktopId) {
            root.activateApp(desktopId, root.appName(desktopId))
        }
        onFileChosen: function (path) {
            root.openPath(path)
        }
        onSettingChosen: function (settingKey) {
            root.showSetting(settingKey)
        }
    }

    TahoeControlCenter {
        id: controlCenter
        anchors.fill: parent
        z: 1000
        reduceMotion: Settings.reduceMotion

        onSettingsRequested: root.activateApp("settings", qsTr("Settings"))
    }

    TahoeNotificationCenter {
        id: notificationCenter
        anchors.fill: parent
        z: 1000
        reduceMotion: Settings.reduceMotion
    }

    // List of applications with an open window, for the Dock's running indicators.
    // It reads windows.count, so the binding updates whenever a window opens or closes.
    function runningItemList() {
        var list = []
        for (var row = 0; row < windowLayer.windows.count; ++row) {
            var entry = windowLayer.windows.get(row)
            list.push({ "id": entry.appId, "label": entry.title })
        }
        return list
    }
}
