import QtQuick
import Tahoe.Services 1.0
import "../tokens"
import "."

/* Project Tahoe X86 Control Center.
 *
 * Quick access to the settings that are actually implemented. Every control here writes to
 * the shared Settings singleton, so the change is immediately visible across the shell and
 * is persisted by the shell's debounced save.
 *
 * What is deliberately absent: network, sound, Bluetooth, and power controls. The shell has
 * no working backend for them yet, and showing dead switches would be worse than showing
 * none. The System section states this instead.
 */
Item {
    id: controlCenter

    property bool reduceMotion: false

    signal dismissed()
    signal settingsRequested()

    function open() {
        visible = true
    }

    function close() {
        visible = false
        dismissed()
    }

    visible: false
    focus: visible
    Keys.onEscapePressed: close()

    MouseArea {
        anchors.fill: parent
        onClicked: controlCenter.close()
    }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: DesignTokens.spacingSmall
        anchors.rightMargin: DesignTokens.spacingSmall
        width: 320
        height: contentColumn.implicitHeight + DesignTokens.spacingDefault * 2
        radius: DesignTokens.radiusPanel
        color: DesignTokens.bgGlass
        border.width: 1
        border.color: DesignTokens.borderGlass

        MouseArea {
            anchors.fill: parent
            // Keep clicks inside the panel from dismissing it.
        }

        Column {
            id: contentColumn
            anchors.top: parent.top
            anchors.topMargin: DesignTokens.spacingDefault
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: DesignTokens.spacingDefault
            anchors.rightMargin: DesignTokens.spacingDefault
            spacing: DesignTokens.spacingDefault

            Text {
                text: qsTr("Control Center")
                color: DesignTokens.textPrimary
                font.pixelSize: DesignTokens.fontSizeTitle
                font.bold: true
            }

            // ---- Appearance ----
            Text {
                text: qsTr("APPEARANCE")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
            }

            Row {
                spacing: DesignTokens.spacingSmall

                Repeater {
                    model: [
                        { "label": qsTr("Dark"), "mode": "dark" },
                        { "label": qsTr("Light"), "mode": "light" }
                    ]

                    delegate: Rectangle {
                        width: 92
                        height: 30
                        radius: DesignTokens.radiusSmall
                        color: Settings.appearanceMode === modelData.mode
                               ? DesignTokens.accent
                               : (modeMouse.containsMouse ? DesignTokens.bgRaised : DesignTokens.bgBase)
                        border.width: 1
                        border.color: DesignTokens.borderDefault

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: Settings.appearanceMode === modelData.mode ? "#ffffff"
                                                                             : DesignTokens.textPrimary
                            font.pixelSize: DesignTokens.fontSizeBody
                        }

                        MouseArea {
                            id: modeMouse
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
                    width: contentColumn.width - 60
                    text: qsTr("Reduce motion")
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }

                TahoeToggle {
                    checked: Settings.reduceMotion
                    reduceMotion: controlCenter.reduceMotion
                    onToggled: function (value) { Settings.reduceMotion = value }
                }
            }

            // ---- Dock ----
            Text {
                text: qsTr("DOCK")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
            }

            Row {
                spacing: DesignTokens.spacingSmall

                Text {
                    width: contentColumn.width - 60
                    text: qsTr("Icon size: %1 px").arg(Settings.dockIconSize)
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            TahoeSlider {
                width: contentColumn.width
                from: 32
                to: 96
                step: 2
                value: Settings.dockIconSize
                reduceMotion: controlCenter.reduceMotion
                onMoved: function (value) { Settings.dockIconSize = value }
            }

            Row {
                spacing: DesignTokens.spacingSmall

                Text {
                    width: contentColumn.width - 60
                    text: qsTr("Magnification")
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }

                TahoeToggle {
                    checked: Settings.dockMagnification
                    reduceMotion: controlCenter.reduceMotion
                    onToggled: function (value) { Settings.dockMagnification = value }
                }
            }

            Row {
                spacing: DesignTokens.spacingSmall

                Text {
                    width: contentColumn.width - 60
                    text: qsTr("Automatically hide the Dock")
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }

                TahoeToggle {
                    checked: Settings.dockAutoHide
                    reduceMotion: controlCenter.reduceMotion
                    onToggled: function (value) { Settings.dockAutoHide = value }
                }
            }

            // ---- Notifications ----
            Text {
                text: qsTr("NOTIFICATIONS")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
            }

            Text {
                width: contentColumn.width
                text: NotificationService.count === 0
                      ? qsTr("No notifications")
                      : qsTr("%1 notifications, %2 unread")
                            .arg(NotificationService.count).arg(NotificationService.unreadCount)
                color: DesignTokens.textPrimary
                font.pixelSize: DesignTokens.fontSizeBody
                wrapMode: Text.WordWrap
            }

            Text {
                width: contentColumn.width
                text: NotificationService.dbusStatus
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: 150
                height: 28
                radius: DesignTokens.radiusSmall
                color: testMouse.containsMouse ? DesignTokens.bgRaised : DesignTokens.bgBase
                border.width: 1
                border.color: DesignTokens.borderDefault

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Send test notification")
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeCaption
                }

                MouseArea {
                    id: testMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: NotificationService.notify(qsTr("Tahoe Shell"),
                                                          qsTr("Test notification"),
                                                          qsTr("This notification came from the shell "
                                                               "itself, through the same service that "
                                                               "applications use."), 1)
                }
            }

            // ---- System ----
            Text {
                text: qsTr("SYSTEM")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
            }

            Text {
                width: contentColumn.width
                text: qsTr("Network, sound, Bluetooth, and power controls are not implemented yet. "
                           + "They will appear here only once the shell can read and change real "
                           + "hardware state.")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: 150
                height: 28
                radius: DesignTokens.radiusSmall
                color: settingsMouse.containsMouse ? DesignTokens.bgRaised : DesignTokens.bgBase
                border.width: 1
                border.color: DesignTokens.borderDefault

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Open Settings\u2026")
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeCaption
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        controlCenter.close()
                        controlCenter.settingsRequested()
                    }
                }
            }
        }
    }
}
