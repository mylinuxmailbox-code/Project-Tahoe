import QtQuick
import Tahoe.Services 1.0
import "../../shared/tokens"

/* Project Tahoe X86 Settings application.
 *
 * Every switch, slider, and field here changes the shared Settings singleton, which the
 * whole shell reads. The shell writes the changed values to
 * $XDG_CONFIG_HOME/project-tahoe/shell/settings.json through the SettingsStore service, so a
 * change survives a restart.
 *
 * Honesty rules:
 *  - Controls that would have no effect are absent. Dock position, for example, is not
 *    offered because the Dock only implements the bottom edge; the property still exists in
 *    the config file and is listed as planned.
 *  - The persistence path and the notification service status are shown verbatim, because
 *    both are things a user may need to check.
 */
Item {
    id: settingsApp

    property var windowFrame: null
    property bool reduceMotion: false
    property string section: "appearance"

    // The shell sets Settings.requestedSection when a Spotlight result names a setting.
    readonly property var knownSections: ["appearance", "wallpaper", "dock", "windows",
                                          "notifications", "storage"]

    function sectionTitle(key) {
        if (key === "appearance")
            return qsTr("Appearance")
        if (key === "wallpaper")
            return qsTr("Wallpaper")
        if (key === "dock")
            return qsTr("Dock")
        if (key === "windows")
            return qsTr("Windows")
        if (key === "notifications")
            return qsTr("Notifications")
        return qsTr("Storage")
    }

    // Spotlight results name a setting, not a section, so they are translated here.
    function sectionForSetting(settingKey) {
        if (settingKey === "appearanceMode" || settingKey === "reduceMotion")
            return "appearance"
        if (settingKey === "wallpaperSource")
            return "wallpaper"
        if (settingKey === "dockIconSize" || settingKey === "dockMagnification"
                || settingKey === "dockAutoHide")
            return "dock"
        if (settingKey === "windowCornerRadius")
            return "windows"
        return "appearance"
    }

    Connections {
        target: Settings

        function onRequestedSectionChanged() {
            if (Settings.requestedSection.length > 0) {
                settingsApp.section = settingsApp.sectionForSetting(Settings.requestedSection)
                Settings.requestedSection = ""
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: DesignTokens.bgPanel

        // ---- Sidebar ----
        Rectangle {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 172
            color: DesignTokens.bgBase

            ListView {
                anchors.fill: parent
                anchors.margins: DesignTokens.spacingSmall
                model: settingsApp.knownSections
                spacing: 2
                clip: true

                delegate: Rectangle {
                    width: parent ? parent.width : 0
                    height: 28
                    radius: DesignTokens.radiusSmall
                    color: settingsApp.section === modelData ? DesignTokens.accent
                                                            : (sectionMouse.containsMouse
                                                               ? DesignTokens.bgRaised
                                                               : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: DesignTokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        text: settingsApp.sectionTitle(modelData)
                        color: settingsApp.section === modelData ? "#ffffff"
                                                                : DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                    }

                    MouseArea {
                        id: sectionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: settingsApp.section = modelData
                    }
                }
            }
        }

        // ---- Content ----
        Item {
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: DesignTokens.spacingLarge

            // ---- Appearance ----
            Column {
                width: parent.width
                visible: settingsApp.section === "appearance"
                spacing: DesignTokens.spacingDefault

                Text {
                    text: qsTr("Appearance")
                    color: DesignTokens.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Row {
                    spacing: DesignTokens.spacingSmall

                    Repeater {
                        model: [
                            { "label": qsTr("Dark"), "mode": "dark" },
                            { "label": qsTr("Light"), "mode": "light" }
                        ]

                        delegate: Rectangle {
                            width: 110
                            height: 32
                            radius: DesignTokens.radiusSmall
                            color: Settings.appearanceMode === modelData.mode
                                   ? DesignTokens.accent
                                   : (appearanceMouse.containsMouse ? DesignTokens.bgRaised
                                                                    : DesignTokens.bgBase)
                            border.width: 1
                            border.color: DesignTokens.borderDefault

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Settings.appearanceMode === modelData.mode
                                       ? "#ffffff" : DesignTokens.textPrimary
                                font.pixelSize: DesignTokens.fontSizeBody
                            }

                            MouseArea {
                                id: appearanceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Settings.appearanceMode = modelData.mode
                            }
                        }
                    }
                }

                Row {
                    spacing: DesignTokens.spacingSmall

                    Text {
                        width: 260
                        text: qsTr("Reduce motion")
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TahoeToggle {
                        checked: Settings.reduceMotion
                        reduceMotion: settingsApp.reduceMotion
                        onToggled: function (value) { Settings.reduceMotion = value }
                    }
                }
            }

            // ---- Wallpaper ----
            Column {
                width: parent.width
                visible: settingsApp.section === "wallpaper"
                spacing: DesignTokens.spacingDefault

                Text {
                    text: qsTr("Wallpaper")
                    color: DesignTokens.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: qsTr("Paste the path of an image file, or an http(s) URL. The desktop "
                               + "loads it with the image loader and reports the real error if it "
                               + "cannot be displayed.")
                    color: DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: Math.min(parent.width, 460)
                    height: 30
                    radius: DesignTokens.radiusSmall
                    color: DesignTokens.bgBase
                    border.width: 1
                    border.color: DesignTokens.borderDefault

                    TextInput {
                        id: wallpaperInput
                        anchors.fill: parent
                        anchors.margins: DesignTokens.spacingSmall
                        verticalAlignment: TextInput.AlignVCenter
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        selectByMouse: true
                        text: Settings.wallpaperSource
                        onTextEdited: Settings.wallpaperSource = text
                    }
                }

                Row {
                    spacing: DesignTokens.spacingSmall

                    Rectangle {
                        width: clearLabel.implicitWidth + DesignTokens.spacingDefault * 2
                        height: 28
                        radius: DesignTokens.radiusSmall
                        color: clearMouse.containsMouse ? DesignTokens.bgRaised : DesignTokens.bgBase
                        border.width: 1
                        border.color: DesignTokens.borderDefault

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: qsTr("Use the default gradient")
                            color: DesignTokens.textPrimary
                            font.pixelSize: DesignTokens.fontSizeCaption
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Settings.wallpaperSource = ""
                                wallpaperInput.text = ""
                            }
                        }
                    }
                }
            }

            // ---- Dock ----
            Column {
                width: parent.width
                visible: settingsApp.section === "dock"
                spacing: DesignTokens.spacingDefault

                Text {
                    text: qsTr("Dock")
                    color: DesignTokens.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    text: qsTr("Icon size: %1 px").arg(Settings.dockIconSize)
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                }

                TahoeSlider {
                    width: Math.min(parent.width, 420)
                    from: 32
                    to: 96
                    step: 2
                    value: Settings.dockIconSize
                    reduceMotion: settingsApp.reduceMotion
                    onMoved: function (value) { Settings.dockIconSize = value }
                }

                Row {
                    spacing: DesignTokens.spacingSmall

                    Text {
                        width: 260
                        text: qsTr("Magnification")
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TahoeToggle {
                        checked: Settings.dockMagnification
                        reduceMotion: settingsApp.reduceMotion
                        onToggled: function (value) { Settings.dockMagnification = value }
                    }
                }

                Text {
                    text: qsTr("Magnification strength: %1")
                        .arg(Settings.dockMagnificationStrength.toFixed(2))
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                }

                TahoeSlider {
                    width: Math.min(parent.width, 420)
                    from: 0
                    to: 1
                    step: 0.05
                    value: Settings.dockMagnificationStrength
                    reduceMotion: settingsApp.reduceMotion
                    onMoved: function (value) { Settings.dockMagnificationStrength = value }
                }

                Row {
                    spacing: DesignTokens.spacingSmall

                    Text {
                        width: 260
                        text: qsTr("Automatically hide the Dock")
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TahoeToggle {
                        checked: Settings.dockAutoHide
                        reduceMotion: settingsApp.reduceMotion
                        onToggled: function (value) { Settings.dockAutoHide = value }
                    }
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: qsTr("Dock position is stored in the configuration file but is not offered "
                               + "here yet: the Dock currently implements the bottom edge only.")
                    color: DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                    wrapMode: Text.WordWrap
                }
            }

            // ---- Windows ----
            Column {
                width: parent.width
                visible: settingsApp.section === "windows"
                spacing: DesignTokens.spacingDefault

                Text {
                    text: qsTr("Windows")
                    color: DesignTokens.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    text: qsTr("Corner radius: %1 px").arg(Settings.windowCornerRadius)
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                }

                TahoeSlider {
                    width: Math.min(parent.width, 420)
                    from: 0
                    to: 24
                    step: 1
                    value: Settings.windowCornerRadius
                    reduceMotion: settingsApp.reduceMotion
                    onMoved: function (value) { Settings.windowCornerRadius = value }
                }

                Row {
                    spacing: DesignTokens.spacingSmall

                    Text {
                        width: 260
                        text: qsTr("Show title bars")
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TahoeToggle {
                        checked: Settings.showWindowTitleBars
                        reduceMotion: settingsApp.reduceMotion
                        onToggled: function (value) { Settings.showWindowTitleBars = value }
                    }
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: qsTr("These apply to the windows this shell hosts. Applications launched "
                               + "separately are managed by the compositor, which owns their "
                               + "decoration and geometry.")
                    color: DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                    wrapMode: Text.WordWrap
                }
            }

            // ---- Notifications ----
            Column {
                width: parent.width
                visible: settingsApp.section === "notifications"
                spacing: DesignTokens.spacingDefault

                Text {
                    text: qsTr("Notifications")
                    color: DesignTokens.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: NotificationService.dbusStatus
                    color: DesignTokens.textSecondary
                    font.pixelSize: DesignTokens.fontSizeBody
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: qsTr("Held notifications: %1").arg(NotificationService.count)
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                }

                Row {
                    spacing: DesignTokens.spacingSmall

                    Rectangle {
                        width: sendLabel.implicitWidth + DesignTokens.spacingDefault * 2
                        height: 28
                        radius: DesignTokens.radiusSmall
                        color: sendMouse.containsMouse ? DesignTokens.bgRaised : DesignTokens.bgBase
                        border.width: 1
                        border.color: DesignTokens.borderDefault

                        Text {
                            id: sendLabel
                            anchors.centerIn: parent
                            text: qsTr("Send a test notification")
                            color: DesignTokens.textPrimary
                            font.pixelSize: DesignTokens.fontSizeCaption
                        }

                        MouseArea {
                            id: sendMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NotificationService.notify(qsTr("Tahoe Shell"),
                                                                  qsTr("Test notification"),
                                                                  qsTr("Raised through the same service "
                                                                       + "applications use."), 1)
                        }
                    }

                    Rectangle {
                        width: clearAllLabel.implicitWidth + DesignTokens.spacingDefault * 2
                        height: 28
                        radius: DesignTokens.radiusSmall
                        visible: NotificationService.count > 0
                        color: clearAllMouse.containsMouse ? DesignTokens.bgRaised : DesignTokens.bgBase
                        border.width: 1
                        border.color: DesignTokens.borderDefault

                        Text {
                            id: clearAllLabel
                            anchors.centerIn: parent
                            text: qsTr("Clear all")
                            color: DesignTokens.textPrimary
                            font.pixelSize: DesignTokens.fontSizeCaption
                        }

                        MouseArea {
                            id: clearAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NotificationService.dismissAll()
                        }
                    }
                }
            }

            // ---- Storage ----
            Column {
                width: parent.width
                visible: settingsApp.section === "storage"
                spacing: DesignTokens.spacingDefault

                Text {
                    text: qsTr("Storage")
                    color: DesignTokens.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: qsTr("Settings file")
                    color: DesignTokens.textSecondary
                    font.pixelSize: DesignTokens.fontSizeBody
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: SettingsStore.configPath
                    color: DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: SettingsStore.status
                    color: DesignTokens.textSecondary
                    font.pixelSize: DesignTokens.fontSizeCaption
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width - DesignTokens.spacingLarge
                    text: qsTr("Trash: %1 items, %2 bytes at %3")
                        .arg(TrashService.count).arg(TrashService.sizeBytes)
                        .arg(TrashService.trashPath)
                    color: DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                    wrapMode: Text.WrapAnywhere
                }

                Rectangle {
                    width: refreshLabel.implicitWidth + DesignTokens.spacingDefault * 2
                    height: 28
                    radius: DesignTokens.radiusSmall
                    color: refreshMouse.containsMouse ? DesignTokens.bgRaised : DesignTokens.bgBase
                    border.width: 1
                    border.color: DesignTokens.borderDefault

                    Text {
                        id: refreshLabel
                        anchors.centerIn: parent
                        text: qsTr("Reload preferences from disk")
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeCaption
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            var values = SettingsStore.load()
                            Settings.applyConfig(values)
                        }
                    }
                }
            }
        }
    }
}
