import QtQuick
import "../tokens"

/* Project Tahoe X86 in-shell window frame.
 *
 * Chrome for applications this shell hosts (Finder, Settings, and other QML apps). It
 * provides real behaviour, not decoration:
 *   - the title bar drags the window, clamped so it cannot be lost off-screen
 *   - eight resize handles change the real geometry, honouring minimum sizes
 *   - clicking anywhere in the window raises it in the window layer (focus follows click)
 *   - close / minimise / zoom buttons emit signals the layer acts on
 *
 * Geometry is owned by this item once it exists: the layer supplies the initial values and
 * receives updates back, so a drag is never fighting a binding.
 *
 * Applications launched through the application registry are separate processes with
 * compositor-managed windows; they are NOT framed by this component.
 */
Item {
    id: frame

    // Applications place their UI directly inside the frame.
    default property alias content: contentHost.data

    property string title: qsTr("Window")
    property string appId: ""
    property bool isActive: false
    property bool isMinimized: false
    property bool isZoomed: false
    property bool showTitleBar: true
    property bool reduceMotion: false
    property int minimumWidth: 360
    property int minimumHeight: 240
    property int cornerRadius: DesignTokens.radiusDefault
    property int titleBarHeight: 30

    // Geometry restored when a zoomed window is un-zoomed.
    property rect restoredGeometry: Qt.rect(0, 0, 0, 0)

    signal closeRequested()
    signal minimizeRequested()
    signal zoomRequested()
    signal focusRequested()

    // ---- Geometry helpers -------------------------------------------------------------

    function clampX(value, frameWidth) {
        var limit = parent ? parent.width - frameWidth : value
        return Math.max(0, Math.min(value, limit))
    }

    function clampY(value, frameHeight) {
        var limit = parent ? parent.height - frameHeight : value
        return Math.max(0, Math.min(value, limit))
    }

    function applyGeometry(newX, newY, newWidth, newHeight) {
        width = Math.round(Math.max(minimumWidth, newWidth))
        height = Math.round(Math.max(minimumHeight, newHeight))
        x = clampX(Math.round(newX), width)
        y = clampY(Math.round(newY), height)
    }

    function zoomToFill() {
        if (!parent)
            return
        restoredGeometry = Qt.rect(x, y, width, height)
        x = 0
        y = 0
        width = parent.width
        height = parent.height
    }

    function restoreFromZoom() {
        if (restoredGeometry.width <= 0 || restoredGeometry.height <= 0)
            return
        x = restoredGeometry.x
        y = restoredGeometry.y
        width = restoredGeometry.width
        height = restoredGeometry.height
    }

    // ---- Drag state -------------------------------------------------------------------

    property var dragOrigin: null

    function beginDrag(pointX, pointY) {
        dragOrigin = { "px": pointX, "py": pointY, "x": x, "y": y }
    }

    function continueDrag(pointX, pointY) {
        if (!dragOrigin)
            return
        var dx = pointX - dragOrigin.px
        var dy = pointY - dragOrigin.py
        x = clampX(dragOrigin.x + dx, width)
        y = clampY(dragOrigin.y + dy, height)
    }

    function endDrag() {
        dragOrigin = null
    }

    // ---- Resize state -----------------------------------------------------------------

    property var resizeOrigin: null

    function beginResize(edge, pointX, pointY) {
        resizeOrigin = { "edge": edge, "px": pointX, "py": pointY,
                         "x": x, "y": y, "w": width, "h": height }
    }

    function continueResize(pointX, pointY) {
        if (!resizeOrigin)
            return

        var origin = resizeOrigin
        var dx = pointX - origin.px
        var dy = pointY - origin.py

        var newX = origin.x
        var newY = origin.y
        var newWidth = origin.w
        var newHeight = origin.h

        if (origin.edge.indexOf("left") >= 0) {
            newX = origin.x + dx
            newWidth = origin.w - dx
        }
        if (origin.edge.indexOf("right") >= 0)
            newWidth = origin.w + dx
        if (origin.edge.indexOf("top") >= 0) {
            newY = origin.y + dy
            newHeight = origin.h - dy
        }
        if (origin.edge.indexOf("bottom") >= 0)
            newHeight = origin.h + dy

        // Keep the opposite edge pinned when a minimum size is reached.
        if (newWidth < minimumWidth) {
            newWidth = minimumWidth
            if (origin.edge.indexOf("left") >= 0)
                newX = origin.x + origin.w - minimumWidth
        }
        if (newHeight < minimumHeight) {
            newHeight = minimumHeight
            if (origin.edge.indexOf("top") >= 0)
                newY = origin.y + origin.h - minimumHeight
        }

        applyGeometry(newX, newY, newWidth, newHeight)
    }

    function endResize() {
        resizeOrigin = null
    }

    // ---- Frame ------------------------------------------------------------------------

    opacity: isMinimized ? 0 : 1
    visible: !isMinimized

    Behavior on opacity {
        enabled: !frame.reduceMotion
        NumberAnimation { duration: DesignTokens.animationFast }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: frame.cornerRadius
        color: DesignTokens.bgRaised
        border.width: 1
        border.color: frame.isActive ? DesignTokens.accent : DesignTokens.borderDefault
        clip: true

        // ---- Title bar ----
        Item {
            id: titleBar
            visible: frame.showTitleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: frame.showTitleBar ? frame.titleBarHeight : 0
            z: 2

            Rectangle {
                anchors.fill: parent
                color: frame.isActive ? DesignTokens.bgPanel : DesignTokens.bgBase
                opacity: frame.isActive ? 1.0 : 0.85
            }

            Row {
                id: buttons
                anchors.left: parent.left
                anchors.leftMargin: DesignTokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: DesignTokens.spacingTiny + 2

                Repeater {
                    model: [
                        { "kind": "close", "color": "#ff5f57" },
                        { "kind": "minimize", "color": "#febc2e" },
                        { "kind": "zoom", "color": "#28c840" }
                    ]

                    delegate: Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: modelData.color
                        // Dimmed when the window is not focused, matching platform behaviour.
                        opacity: frame.isActive ? 1.0 : 0.55

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.ArrowCursor
                            onClicked: {
                                if (modelData.kind === "close")
                                    frame.closeRequested()
                                else if (modelData.kind === "minimize")
                                    frame.minimizeRequested()
                                else
                                    frame.zoomRequested()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: frame.title
                color: frame.isActive ? DesignTokens.textPrimary : DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeBody
                font.bold: frame.isActive
                elide: Text.ElideMiddle
                width: Math.max(0, parent.width - buttons.width - DesignTokens.spacingLarge * 2)
                horizontalAlignment: Text.AlignHCenter
            }

            // Drag surface. Excludes the buttons by sitting behind them in the stack and
            // only starting a drag on a press that did not land on a button.
            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.leftMargin: buttons.width + DesignTokens.spacingLarge
                anchors.rightMargin: DesignTokens.spacingLarge
                z: -1
                enabled: !frame.isZoomed
                cursorShape: Qt.ArrowCursor

                onPressed: {
                    frame.focusRequested()
                    var point = mapToItem(frame.parent, mouse.x, mouse.y)
                    frame.beginDrag(point.x, point.y)
                }
                onPositionChanged: {
                    if (!pressed)
                        return
                    var point = mapToItem(frame.parent, mouse.x, mouse.y)
                    frame.continueDrag(point.x, point.y)
                }
                onReleased: frame.endDrag()
                onCanceled: frame.endDrag()
            }

            MouseArea {
                anchors.fill: parent
                z: -2
                onPressed: frame.focusRequested()
            }
        }

        // ---- Application content ----
        Item {
            id: contentHost
            anchors.top: titleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }

        // ---- Resize handles ----
        MouseArea {
            id: handleLeft
            width: 5
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: frame.cornerRadius
            anchors.bottomMargin: frame.cornerRadius
            visible: !frame.isZoomed
            cursorShape: Qt.SizeHorCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("left", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

        MouseArea {
            id: handleRight
            width: 5
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: frame.cornerRadius
            anchors.bottomMargin: frame.cornerRadius
            visible: !frame.isZoomed
            cursorShape: Qt.SizeHorCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("right", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

        MouseArea {
            height: 5
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: frame.cornerRadius
            anchors.rightMargin: frame.cornerRadius
            visible: !frame.isZoomed
            cursorShape: Qt.SizeVerCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("top", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

        MouseArea {
            height: 5
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: frame.cornerRadius
            anchors.rightMargin: frame.cornerRadius
            visible: !frame.isZoomed
            cursorShape: Qt.SizeVerCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("bottom", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

        MouseArea {
            width: 12
            height: 12
            anchors.left: parent.left
            anchors.top: parent.top
            visible: !frame.isZoomed
            cursorShape: Qt.SizeFDiagCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("topleft", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

        MouseArea {
            width: 12
            height: 12
            anchors.right: parent.right
            anchors.top: parent.top
            visible: !frame.isZoomed
            cursorShape: Qt.SizeBDiagCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("topright", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

        MouseArea {
            width: 12
            height: 12
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            visible: !frame.isZoomed
            cursorShape: Qt.SizeBDiagCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("bottomleft", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }

        MouseArea {
            width: 12
            height: 12
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: !frame.isZoomed
            cursorShape: Qt.SizeFDiagCursor
            enabled: !frame.isZoomed

            onPressed: {
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.beginResize("bottomright", point.x, point.y)
            }
            onPositionChanged: {
                if (!pressed)
                    return
                var point = mapToItem(frame.parent, mouse.x, mouse.y)
                frame.continueResize(point.x, point.y)
            }
            onReleased: frame.endResize()
            onCanceled: frame.endResize()
        }
    }
}
