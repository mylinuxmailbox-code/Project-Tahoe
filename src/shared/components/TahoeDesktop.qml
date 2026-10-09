import QtQuick
import "../tokens"

/* Project Tahoe X86 desktop surface.
 *
 * Implemented:
 *  - a wallpaper layer that renders an image when wallpaperSource is set, and otherwise
 *    falls back to a plain gradient (honest default: no wallpaper image ships with the
 *    project, and none is invented)
 *  - a desktop context-menu-free placeholder area
 *
 * NOT implemented yet:
 *  - desktop files and folders, selection, drag and drop, rename/copy/move/delete
 *  - desktop widgets
 *  - per-display wallpaper assignment
 *
 * Deliberately absent: a fake right-click menu with items that do nothing.
 */
Item {
    id: root

    // Set to a real image path to show a wallpaper. Empty means the gradient fallback.
    property string wallpaperSource: ""
    property bool wallpaperAvailable: wallpaperSource.length > 0

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: DesignTokens.isDark ? "#12161c" : "#dfe5ee"
            }
            GradientStop {
                position: 1.0
                color: DesignTokens.isDark ? "#0a0c10" : "#f2f4f7"
            }
        }

        Image {
            anchors.fill: parent
            source: root.wallpaperAvailable ? root.wallpaperSource : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.wallpaperAvailable
            onStatusChanged: {
                if (status === Image.Error) {
                    // Report rather than silently showing a broken image.
                    wallpaperError = true
                }
            }
        }
    }

    // Surfaced to the caller so a failed wallpaper load can be reported instead of hidden.
    property bool wallpaperError: false
}
