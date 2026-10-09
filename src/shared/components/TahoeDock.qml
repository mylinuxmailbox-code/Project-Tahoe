import QtQuick
import "../tokens"

/* Project Tahoe X86 Dock.
 *
 * Status: PARTIAL implementation. Nothing here launches applications yet.
 *
 * Implemented:
 *  - pinned + running item model with an explicit API and change-notifying updates
 *  - per-item activation signal wired to a real mouse area
 *  - hover magnification (single-tile scale; macOS-style neighbour magnification not yet)
 *  - optional auto-hide with a bottom edge reveal strip
 *  - running-app indicator dots derived from real runningItems state
 *
 * Not implemented yet:
 *  - application launching (must route through the AppLaunch service, still a contract stub)
 *  - drag-and-drop pinning and reordering
 *  - downloads stack and trash
 *  - app icons (tiles currently render the item label as a deliberate placeholder)
 */
Item {
    id: root

    // Model
    property var pinnedItems: []
    property var runningItems: []
    property int activeItemId: -1

    // Appearance / behavior
    property int iconSize: 48
    property bool magnification: true
    property real magnificationStrength: 0.3
    property bool autoHide: false
    property bool reduceMotion: false
    property int spacing: 24

    readonly property int handleHeight: 6
    readonly property bool hidden: autoHide && !revealArea.containsMouse

    signal itemActivated(var item)

    implicitHeight: iconSize + 16
    implicitWidth: bar.implicitWidth + spacing * 2

    // Model API. Assignments (not in-place mutation) keep QML bindings updated.
    function addPinnedItem(item) {
        var next = pinnedItems.slice()
        next.push(item)
        pinnedItems = next
    }

    function removePinnedItem(item) {
        pinnedItems = pinnedItems.filter(function (entry) { return entry.id !== item.id })
    }

    function setRunningItems(items) {
        runningItems = items
    }

    function isRunning(id) {
        for (var i = 0; i < runningItems.length; i++) {
            if (runningItems[i].id === id)
                return true
        }
        return false
    }

    function currentItems() {
        var result = []
        var seen = {}
        var sources = [pinnedItems, runningItems]
        for (var s = 0; s < sources.length; s++) {
            var entries = sources[s]
            for (var i = 0; i < entries.length; i++) {
                var entry = entries[i]
                if (seen[entry.id])
                    continue
                seen[entry.id] = true
                result.push(entry)
            }
        }
        return result
    }

    // Bottom-edge reveal strip. Stays behind the dock surface so tiles receive clicks
    // while the dock is shown, and becomes the only hover target while it is hidden.
    MouseArea {
        id: revealArea
        z: -1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.handleHeight
        hoverEnabled: true
    }

    Rectangle {
        id: surface
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.height
        y: root.hidden ? root.height - root.handleHeight : 0
        enabled: !root.hidden
        color: DesignTokens.bgGlass
        border.color: DesignTokens.borderGlass
        border.width: 1

        Behavior on y {
            NumberAnimation {
                duration: root.reduceMotion ? 0 : DesignTokens.animationNormal
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: bar
            anchors.centerIn: parent
            spacing: root.spacing

            Repeater {
                model: root.currentItems()

                delegate: Item {
                    id: tile
                    width: root.iconSize
                    height: root.iconSize

                    readonly property bool isActive: modelData.id === root.activeItemId
                    readonly property bool isRunning: root.isRunning(modelData.id)
                    readonly property bool isHovered: hoverArea.containsMouse
                    readonly property real restScale: isActive ? 1 + root.magnificationStrength * 0.5 : 1

                    scale: (root.magnification && isHovered && !root.reduceMotion)
                           ? 1 + root.magnificationStrength
                           : restScale

                    Behavior on scale {
                        NumberAnimation {
                            duration: root.reduceMotion ? 0 : DesignTokens.animationFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        id: frame
                        anchors.fill: parent
                        radius: DesignTokens.radiusDefault
                        color: tile.isActive ? DesignTokens.bgRaised : DesignTokens.bgPanel
                        border.width: tile.isActive ? 2 : 1
                        border.color: tile.isActive ? DesignTokens.accent : DesignTokens.borderDefault

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - DesignTokens.spacingTiny * 2
                            text: modelData.label ? modelData.label : modelData.id
                            color: DesignTokens.textPrimary
                            font.pixelSize: DesignTokens.fontSizeCaption
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }

                    // Running indicator, shown only for items reported as running.
                    Rectangle {
                        visible: tile.isRunning
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -DesignTokens.spacingTiny
                        width: DesignTokens.spacingTiny
                        height: DesignTokens.spacingTiny
                        radius: width / 2
                        color: DesignTokens.textMuted
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.itemActivated(modelData)
                    }
                }
            }
        }
    }
}
