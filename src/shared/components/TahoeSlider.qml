import QtQuick
import "../tokens"

/* Project Tahoe X86 value slider.
 *
 * A real slider: press or drag anywhere on the track to set the value, clamped to
 * [from, to] and snapped to `step`. Emits moved(value) on every change.
 */
Item {
    id: slider

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1

    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 22

    function setFromPosition(positionX) {
        if (width <= 0)
            return

        var ratio = Math.max(0, Math.min(1, positionX / width))
        var raw = from + ratio * (to - from)

        if (step > 0)
            raw = Math.round(raw / step) * step

        var clamped = Math.max(from, Math.min(to, raw))
        if (clamped !== value) {
            value = clamped
            moved(clamped)
        }
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 4
        radius: 2
        color: DesignTokens.bgBase
        border.width: 1
        border.color: DesignTokens.borderDefault

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: slider.to > slider.from
                   ? parent.width * ((slider.value - slider.from) / (slider.to - slider.from))
                   : 0
            height: parent.height
            radius: parent.radius
            color: DesignTokens.accent
        }
    }

    Rectangle {
        id: knob
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: slider.to > slider.from
           ? (slider.width - width) * ((slider.value - slider.from) / (slider.to - slider.from))
           : 0
        color: "#ffffff"
        border.width: 1
        border.color: DesignTokens.borderDefault
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: function (mouse) { slider.setFromPosition(mouse.x) }
        onPositionChanged: function (mouse) { if (pressed) slider.setFromPosition(mouse.x) }
    }
}
