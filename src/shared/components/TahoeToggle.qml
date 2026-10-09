import QtQuick
import "../tokens"

/* Project Tahoe X86 switch control.
 *
 * A real toggle: clicking it flips `checked`, and dragging the knob across also flips it.
 * It emits toggled(checked) for callers that want to react immediately rather than bind.
 */
Item {
    id: toggle

    property bool checked: false
    property bool enabledControl: true

    // Declared here rather than at the end of the file: it belongs with the other state.
    property bool reduceMotion: false

    signal toggled(bool checked)

    implicitWidth: 40
    implicitHeight: 22

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? DesignTokens.accent : DesignTokens.bgBase
        border.width: 1
        border.color: DesignTokens.borderDefault
        opacity: toggle.enabledControl ? 1 : 0.5

        Rectangle {
            id: knob
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: toggle.checked ? parent.width - width - 3 : 3
            color: "#ffffff"

            Behavior on x {
                enabled: !toggle.reduceMotion
                NumberAnimation { duration: DesignTokens.animationFast }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: toggle.enabledControl
        onClicked: {
            toggle.checked = !toggle.checked
            toggle.toggled(toggle.checked)
        }
    }
}
