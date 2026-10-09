import QtQuick
import Tahoe.Services 1.0
import "../tokens"

/* Project Tahoe X86 Notification Center.
 *
 * The list behind the bell in the menu bar. It renders the real contents of the
 * NotificationService model and reports the service's bus status when it cannot receive
 * notifications from other applications, so an empty list is never mistaken for "nothing
 * happened on this system".
 */
Item {
    id: notificationCenter

    property bool reduceMotion: false

    signal dismissed()

    function open() {
        visible = true
        NotificationService.markAllRead()
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
        onClicked: notificationCenter.close()
    }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: DesignTokens.spacingSmall
        anchors.rightMargin: DesignTokens.spacingSmall
        width: 360
        height: Math.min(460, header.height + listArea.height + DesignTokens.spacingDefault * 2)
        radius: DesignTokens.radiusPanel
        color: DesignTokens.bgGlass
        border.width: 1
        border.color: DesignTokens.borderGlass

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: DesignTokens.spacingDefault
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Notifications")
                color: DesignTokens.textPrimary
                font.pixelSize: DesignTokens.fontSizeTitle
                font.bold: true
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.implicitWidth + DesignTokens.spacingDefault * 2
                height: 22
                radius: DesignTokens.radiusSmall
                visible: NotificationService.count > 0
                color: clearMouse.containsMouse ? DesignTokens.bgRaised : "transparent"

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: qsTr("Clear All")
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeCaption
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: NotificationService.dismissAll()
                }
            }
        }

        Item {
            id: listArea
            anchors.top: header.bottom
            anchors.topMargin: DesignTokens.spacingSmall
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: DesignTokens.spacingDefault
            anchors.leftMargin: DesignTokens.spacingSmall
            anchors.rightMargin: DesignTokens.spacingSmall

            ListView {
                id: list
                anchors.fill: parent
                model: NotificationService
                clip: true
                spacing: DesignTokens.spacingTiny

                delegate: Rectangle {
                    width: list.width
                    height: bodyText.implicitHeight + DesignTokens.spacingDefault * 2 + 20
                    radius: DesignTokens.radiusSmall
                    color: model.isRead ? DesignTokens.bgPanel : DesignTokens.bgRaised
                    border.width: 1
                    border.color: model.urgency === 2 ? DesignTokens.statusError
                                                      : DesignTokens.borderDefault

                    Text {
                        id: titleText
                        anchors.top: parent.top
                        anchors.topMargin: DesignTokens.spacingSmall
                        anchors.left: parent.left
                        anchors.leftMargin: DesignTokens.spacingSmall
                        anchors.right: dismissButton.left
                        anchors.rightMargin: DesignTokens.spacingSmall
                        text: model.appName
                        color: DesignTokens.textMuted
                        font.pixelSize: DesignTokens.fontSizeCaption
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.top: titleText.bottom
                        anchors.left: titleText.left
                        anchors.right: titleText.right
                        text: model.summary
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        id: bodyText
                        anchors.top: parent.top
                        anchors.topMargin: 40
                        anchors.left: titleText.left
                        anchors.right: titleText.right
                        text: model.body
                        color: DesignTokens.textSecondary
                        font.pixelSize: DesignTokens.fontSizeCaption
                        wrapMode: Text.WordWrap
                        visible: text.length > 0
                    }

                    Rectangle {
                        id: dismissButton
                        anchors.top: parent.top
                        anchors.topMargin: DesignTokens.spacingSmall
                        anchors.right: parent.right
                        anchors.rightMargin: DesignTokens.spacingSmall
                        width: 18
                        height: 18
                        radius: 9
                        color: dismissMouse.containsMouse ? DesignTokens.bgBase : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u00d7"
                            color: DesignTokens.textMuted
                            font.pixelSize: DesignTokens.fontSizeBody
                        }

                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NotificationService.dismiss(model.notificationId)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: NotificationService.count === 0
                width: listArea.width - DesignTokens.spacingDefault * 2
                text: {
                    if (NotificationService.count > 0)
                        return ""
                    if (NotificationService.dbusStatus.indexOf("session notification server") >= 0)
                        return qsTr("No notifications")
                    // Explain why the list is empty rather than implying nothing happened.
                    return qsTr("No notifications here.\n\n") + NotificationService.dbusStatus
                }
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeBody
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
