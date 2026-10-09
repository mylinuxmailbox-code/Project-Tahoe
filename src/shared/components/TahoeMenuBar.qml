import QtQuick
import "../tokens"

/* Project Tahoe X86 menu bar.
 *
 * Implemented:
 *  - active application name
 *  - a live clock (updates every second, real system time)
 *  - a status message area used to report service results and failures honestly
 *
 *  - a notification indicator showing the real unread count, which opens the Notification
 *    Center; when the shell cannot receive notifications from other applications, the
 *    indicator says so rather than showing a confident, empty bell
 *  - a Control Center button
 *
 * NOT implemented yet:
 *  - application menus (File/Edit/View/Window/Help) driven by the active application
 *  - status items for network, battery, volume, and Bluetooth, because the shell has no
 *    working backend for them yet
 *  - search entry (use the Spotlight shortcut instead)
 *
 * Deliberately absent: clickable menu titles that would open nothing. They are added
 * when the menu model behind them exists, not before.
 */
Item {
    id: root

    property string activeAppName: "Project Tahoe X86"
    property string statusMessage: ""
    property color statusColor: DesignTokens.textMuted
    property int unreadNotifications: 0
    property bool notificationServiceReady: false

    signal notificationsRequested()
    signal controlCenterRequested()

    implicitHeight: DesignTokens.menuBarHeight

    function refreshClock() {
        clockText = Qt.formatTime(new Date(), "HH:mm")
        dateText = Qt.formatDate(new Date(), "ddd d MMM")
    }

    property string clockText: ""
    property string dateText: ""

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshClock()
    }

    Rectangle {
        anchors.fill: parent
        color: DesignTokens.bgPanel
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: DesignTokens.spacingDefault
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesignTokens.spacingLarge

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.activeAppName
            color: DesignTokens.textPrimary
            font.pixelSize: DesignTokens.fontSizePanel
            font.bold: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusMessage
            color: root.statusColor
            font.pixelSize: DesignTokens.fontSizeCaption
            visible: root.statusMessage.length > 0
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 640)
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: DesignTokens.spacingDefault
        anchors.verticalCenter: parent.verticalCenter
        spacing: DesignTokens.spacingSmall

        Rectangle {
            id: notificationButton
            anchors.verticalCenter: parent.verticalCenter
            width: notificationLabel.implicitWidth + DesignTokens.spacingSmall * 2
            height: 24
            radius: DesignTokens.radiusSmall
            color: notificationMouse.containsMouse ? DesignTokens.bgRaised : "transparent"
            // A dimmed indicator means "this shell is not the session notification server",
            // so the count cannot be trusted to be the whole story.
            opacity: root.notificationServiceReady ? 1.0 : 0.55

            Text {
                id: notificationLabel
                anchors.centerIn: parent
                text: root.unreadNotifications > 0
                      ? qsTr("Notifications (%1)").arg(root.unreadNotifications)
                      : qsTr("Notifications")
                color: root.unreadNotifications > 0 ? DesignTokens.accent
                                                    : DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
            }

            MouseArea {
                id: notificationMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.notificationsRequested()
            }
        }

        Rectangle {
            id: controlCenterButton
            anchors.verticalCenter: parent.verticalCenter
            width: controlLabel.implicitWidth + DesignTokens.spacingSmall * 2
            height: 24
            radius: DesignTokens.radiusSmall
            color: controlMouse.containsMouse ? DesignTokens.bgRaised : "transparent"

            Text {
                id: controlLabel
                anchors.centerIn: parent
                text: qsTr("Control Center")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
            }

            MouseArea {
                id: controlMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.controlCenterRequested()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dateText
            color: DesignTokens.textMuted
            font.pixelSize: DesignTokens.fontSizeCaption
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.clockText
            color: DesignTokens.textSecondary
            font.pixelSize: DesignTokens.fontSizePanel
        }
    }
}
