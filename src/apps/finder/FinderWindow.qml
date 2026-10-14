import QtQuick
import Tahoe.Services 1.0
import "../../shared/tokens"

/* Project Tahoe X86 Finder.
 *
 * A real file browser. Every operation goes through the FileService and TrashService C++
 * services, so navigating, creating, renaming, deleting, and restoring act on the actual
 * filesystem - and every failure is shown to the user rather than swallowed.
 *
 * Deleting moves items to the freedesktop trash, so it is recoverable. Permanent removal is
 * only reachable through the Trash's "Empty Trash" action, which says what it does.
 *
 * Copy, cut, and paste hold a real path, never a copy of the data. Paste goes through
 * FileService, which refuses to overwrite: a name clash is reported, not silently replaced.
 */
Item {
    id: finder

    // Injected by the window layer.
    property var windowFrame: null
    property bool reduceMotion: false

    // A sentinel that switches the browser into trash mode. It is not a real path, so it can
    // never collide with a directory that happens to be called "trash".
    readonly property string trashSentinel: "tahoe:trash"
    readonly property bool trashMode: currentPath === trashSentinel

    property string currentPath: ""
    property var history: []
    property int historyIndex: -1
    property bool showHidden: false
    property var entries: []
    property var trashEntries: []
    property string selectedPath: ""
    property bool renaming: false
    property string renameText: ""
    property string message: ""
    property bool messageIsError: false

    // Copy and cut hold the source path only. Paste reads the filesystem at that moment.
    property string clipboardPath: ""
    property bool clipboardIsCut: false

    function report(text, isError) {
        message = text
        messageIsError = isError === true
    }

    function formatSize(bytes) {
        if (bytes <= 0)
            return ""
        var units = ["B", "KB", "MB", "GB", "TB"]
        var index = 0
        var value = bytes
        while (value >= 1024 && index < units.length - 1) {
            value = value / 1024
            ++index
        }
        return (index === 0 ? value : value.toFixed(1)) + " " + units[index]
    }

    function shortKind(entry) {
        if (entry.isDir)
            return "DIR"
        var name = entry.name
        var dot = name.lastIndexOf(".")
        if (dot > 0 && dot < name.length - 1)
            return name.substring(dot + 1, dot + 5).toUpperCase()
        return "FILE"
    }

    function refresh() {
        if (trashMode) {
            trashEntries = TrashService.items()
            entries = []
            return
        }

        if (currentPath.length === 0) {
            entries = []
            return
        }

        entries = FileService.list(currentPath, showHidden)

        // An empty listing for a directory we cannot read is a permission problem, not an
        // empty folder. Say which one it is instead of showing an empty view.
        if (entries.length === 0) {
            var details = FileService.stat(currentPath)
            if (details && details.isDir === true && details.isReadable !== true)
                report("Cannot read " + currentPath + ": this user has no permission for it", true)
            else
                report(currentPath + " is empty", false)
        }
    }

    function navigate(path, recordHistory) {
        if (path !== trashSentinel && !FileService.isDirectory(path)) {
            report("Cannot open " + path + ": it is not a directory", true)
            return
        }

        currentPath = path
        selectedPath = ""
        renaming = false
        message = ""

        if (recordHistory !== false) {
            // Truncate any forward history, exactly like a browser.
            if (historyIndex < history.length - 1)
                history = history.slice(0, historyIndex + 1)
            history = history.concat([path])
            historyIndex = history.length - 1
        }

        refresh()
        report(path === trashSentinel ? "Trash" : path, false)
    }

    function goBack() {
        if (historyIndex <= 0)
            return
        historyIndex = historyIndex - 1
        navigate(history[historyIndex], false)
    }

    function goForward() {
        if (historyIndex >= history.length - 1)
            return
        historyIndex = historyIndex + 1
        navigate(history[historyIndex], false)
    }

    function goUp() {
        if (trashMode) {
            navigate(homePath(), true)
            return
        }
        var parent = FileService.parentPath(currentPath)
        if (parent === currentPath)
            return
        navigate(parent, true)
    }

    function homePath() {
        var locations = FileService.locations()
        return locations["Home"] !== undefined ? locations["Home"] : "/"
    }

    function openEntry(entry) {
        if (entry.isDir) {
            navigate(entry.path, true)
            return
        }

        var result = AppRegistry.openPath(entry.path)
        if (result === AppRegistry.Started)
            report("Opened " + entry.name, false)
        else
            report(AppRegistry.lastError, true)
    }

    function makeFolder() {
        var result = FileService.makeDirectory(currentPath, "New Folder")
        if (result.ok) {
            report(result.message, false)
            refresh()
        } else {
            report(result.error, true)
        }
    }

    function beginRename() {
        if (selectedPath.length === 0 || trashMode) {
            report("Select an item to rename", true)
            return
        }
        var info = FileService.stat(selectedPath)
        if (!info || info.name === undefined) {
            report("Select an item to rename", true)
            return
        }
        renameText = info.name
        renaming = true
    }

    function commitRename() {
        if (!renaming)
            return

        var newName = renameText
        renaming = false

        var result = FileService.rename(selectedPath, newName)
        if (result.ok) {
            report(result.message, false)
            selectedPath = ""
            refresh()
        } else {
            report(result.error, true)
        }
    }

    function trashSelected() {
        if (selectedPath.length === 0) {
            report("Select something to move to the Trash", true)
            return
        }

        var result = TrashService.trash([selectedPath])
        report(result.ok ? "Moved to the Trash" : result.error, !result.ok)

        selectedPath = ""
        refresh()
    }

    function restoreSelected() {
        if (selectedPath.length === 0) {
            report("Select a trashed item to put back", true)
            return
        }

        var name = selectedPath.substring(selectedPath.lastIndexOf("/") + 1)
        var result = TrashService.restore(name)
        report(result.ok ? "Restored to " + result.restoredTo : result.error, !result.ok)

        selectedPath = ""
        refresh()
    }

    function emptyTrash() {
        var result = TrashService.empty()
        report(result.ok ? "Permanently removed " + result.removed + " items" : result.error,
               !result.ok)
        refresh()
    }

    // ---- Copy, cut, paste, duplicate ----

    function joinPath(dir, name) {
        return dir.endsWith("/") ? dir + name : dir + "/" + name
    }

    function existsAt(path) {
        var info = FileService.stat(path)
        return info !== undefined && info !== null && info.name !== undefined
    }

    // A name that does not collide with anything in the directory: "a.txt" is taken, so
    // "a copy.txt" is tried first, then "a copy 2.txt", and so on.
    function duplicateNameIn(dir, baseName, ext) {
        var candidate = baseName + " copy" + ext
        var n = 2
        while (existsAt(joinPath(dir, candidate))) {
            candidate = baseName + " copy " + n + ext
            ++n
        }
        return candidate
    }

    function duplicateSelected() {
        if (trashMode || selectedPath.length === 0 || !existsAt(selectedPath)) {
            report("Select an item to duplicate", true)
            return
        }

        var name = selectedPath.substring(selectedPath.lastIndexOf("/") + 1)
        var dot = name.lastIndexOf(".")
        var baseName = dot > 0 ? name.substring(0, dot) : name
        var ext = dot > 0 ? name.substring(dot) : ""

        var parent = FileService.parentPath(selectedPath)
        var copyName = duplicateNameIn(parent, baseName, ext)
        var result = FileService.copy(selectedPath, joinPath(parent, copyName))

        if (result.ok) {
            refresh()
            report("Duplicated as " + copyName, false)
        } else {
            report(result.error, true)
        }
    }

    function stageSelected(isCut) {
        if (trashMode || selectedPath.length === 0) {
            report("Select an item to " + (isCut ? "cut" : "copy"), true)
            return
        }
        if (!existsAt(selectedPath)) {
            report("That item no longer exists", true)
            selectedPath = ""
            refresh()
            return
        }

        clipboardPath = selectedPath
        clipboardIsCut = isCut
        var name = selectedPath.substring(selectedPath.lastIndexOf("/") + 1)
        report((isCut ? "Cut " : "Copied ") + name + ". Open a folder and paste to finish.", false)
    }

    function pasteHere() {
        if (trashMode) {
            report("Open a folder to paste into. The Trash cannot receive items.", true)
            return
        }
        if (clipboardPath.length === 0) {
            report("Nothing to paste. Copy or cut an item first.", true)
            return
        }
        if (!existsAt(clipboardPath)) {
            report("The copied item no longer exists", true)
            clipboardPath = ""
            clipboardIsCut = false
            return
        }

        // A folder cannot go inside itself: the copy would never finish.
        var sourceIsDir = FileService.isDirectory(clipboardPath)
        if (sourceIsDir && (currentPath === clipboardPath || currentPath.indexOf(clipboardPath + "/") === 0)) {
            report("A folder cannot be pasted into itself", true)
            return
        }

        // Passing the folder as the destination means "put it inside". FileService refuses
        // when the name is already there, so nothing is overwritten.
        var result = clipboardIsCut
            ? FileService.move(clipboardPath, currentPath)
            : FileService.copy(clipboardPath, currentPath)

        if (result.ok) {
            if (clipboardIsCut) {
                clipboardPath = ""
                clipboardIsCut = false
            }
            refresh()
            report(result.message, false)
        } else {
            report(result.error, true)
        }
    }

    function locationsList() {
        var map = FileService.locations()
        var order = ["Home", "Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos",
                     "Applications", "Root"]
        var list = []
        for (var i = 0; i < order.length; ++i) {
            var label = order[i]
            if (map[label] !== undefined)
                list.push({ "label": label, "path": map[label] })
        }
        return list
    }

    Component.onCompleted: navigate(homePath(), true)

    focus: true

    Keys.onEscapePressed: {
        selectedPath = ""
        renaming = false
    }

    // Standard file-manager shortcuts. Ctrl+C in the rename field is handled by the field
    // itself, because it holds focus while renaming.
    Keys.onPressed: function (event) {
        if (!(event.modifiers & Qt.ControlModifier))
            return
        if (event.key === Qt.Key_C)
            finder.stageSelected(false)
        else if (event.key === Qt.Key_X)
            finder.stageSelected(true)
        else if (event.key === Qt.Key_V)
            finder.pasteHere()
        else if (event.key === Qt.Key_D)
            finder.duplicateSelected()
        else
            return
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        color: DesignTokens.bgPanel

        // ---- Toolbar ----
        Rectangle {
            id: toolbar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40
            color: DesignTokens.bgBase

            Row {
                id: navButtons
                anchors.left: parent.left
                anchors.leftMargin: DesignTokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: DesignTokens.spacingTiny

                Repeater {
                    model: [
                        { "label": "\u2039", "enabled": finder.historyIndex > 0, "action": "back" },
                        { "label": "\u203a",
                          "enabled": finder.historyIndex < finder.history.length - 1,
                          "action": "forward" },
                        { "label": "\u2191", "enabled": true, "action": "up" }
                    ]

                    delegate: Rectangle {
                        width: 28
                        height: 26
                        radius: DesignTokens.radiusSmall
                        color: navMouse.containsMouse && modelData.enabled
                               ? DesignTokens.bgRaised : "transparent"
                        opacity: modelData.enabled ? 1 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: DesignTokens.textPrimary
                            font.pixelSize: DesignTokens.fontSizeTitle
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: modelData.enabled
                            onClicked: {
                                if (modelData.action === "back")
                                    finder.goBack()
                                else if (modelData.action === "forward")
                                    finder.goForward()
                                else
                                    finder.goUp()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.left: navButtons.right
                anchors.leftMargin: DesignTokens.spacingDefault
                anchors.right: toolbarActions.left
                anchors.rightMargin: DesignTokens.spacingDefault
                anchors.verticalCenter: parent.verticalCenter
                text: finder.trashMode ? qsTr("Trash") : finder.currentPath
                color: DesignTokens.textSecondary
                font.pixelSize: DesignTokens.fontSizeBody
                elide: Text.ElideMiddle
            }

            Row {
                id: toolbarActions
                anchors.right: parent.right
                anchors.rightMargin: DesignTokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: DesignTokens.spacingTiny

                Repeater {
                    model: [
                        { "label": qsTr("New Folder"), "action": "mkdir", "needsFile": true },
                        { "label": qsTr("Rename"), "action": "rename", "needsFile": true },
                        { "label": qsTr("Duplicate"), "action": "duplicate", "needsFile": true },
                        { "label": qsTr("Copy"), "action": "copy", "needsFile": true },
                        { "label": qsTr("Cut"), "action": "cut", "needsFile": true },
                        { "label": qsTr("Paste"), "action": "paste", "needsFile": true },
                        { "label": qsTr("Trash"), "action": "trash", "needsFile": true },
                        { "label": qsTr("Restore"), "action": "restore", "needsFile": false },
                        { "label": qsTr("Empty"), "action": "empty", "needsFile": false }
                    ]

                    delegate: Rectangle {
                        // Each action belongs to exactly one mode, so nothing is offered that
                        // cannot work in the location being shown.
                        readonly property bool inMode: modelData.needsFile ? !finder.trashMode
                                                                           : finder.trashMode
                        visible: inMode
                        width: visible ? actionLabel.implicitWidth + DesignTokens.spacingSmall * 2 : 0
                        height: 26
                        radius: DesignTokens.radiusSmall
                        color: actionMouse.containsMouse ? DesignTokens.bgRaised : "transparent"

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: DesignTokens.textPrimary
                            font.pixelSize: DesignTokens.fontSizeCaption
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.action === "mkdir")
                                    finder.makeFolder()
                                else if (modelData.action === "rename")
                                    finder.beginRename()
                                else if (modelData.action === "duplicate")
                                    finder.duplicateSelected()
                                else if (modelData.action === "copy")
                                    finder.stageSelected(false)
                                else if (modelData.action === "cut")
                                    finder.stageSelected(true)
                                else if (modelData.action === "paste")
                                    finder.pasteHere()
                                else if (modelData.action === "trash")
                                    finder.trashSelected()
                                else if (modelData.action === "restore")
                                    finder.restoreSelected()
                                else
                                    finder.emptyTrash()
                            }
                        }
                    }
                }
            }
        }

        // ---- Sidebar ----
        Rectangle {
            id: sidebar
            anchors.top: toolbar.bottom
            anchors.left: parent.left
            anchors.bottom: statusBar.top
            width: 186
            color: DesignTokens.bgPanel

            ListView {
                id: locationsView
                anchors.fill: parent
                anchors.margins: DesignTokens.spacingSmall
                model: finder.locationsList()
                clip: true
                spacing: 2

                delegate: Rectangle {
                    width: locationsView.width
                    height: 28
                    radius: DesignTokens.radiusSmall
                    color: finder.currentPath === modelData.path
                           ? DesignTokens.bgRaised
                           : (locationMouse.containsMouse ? DesignTokens.bgBase : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: DesignTokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                    }

                    MouseArea {
                        id: locationMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: finder.navigate(modelData.path, true)
                    }
                }

                // The Trash entry carries the real item count, so the sidebar never claims
                // the trash is empty when it is not.
                footer: Rectangle {
                    width: locationsView.width
                    height: 28
                    radius: DesignTokens.radiusSmall
                    color: finder.trashMode ? DesignTokens.bgRaised
                                            : (trashMouse.containsMouse ? DesignTokens.bgBase
                                                                        : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: DesignTokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Trash" + (TrashService.count > 0 ? " (" + TrashService.count + ")" : "")
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                    }

                    MouseArea {
                        id: trashMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: finder.navigate(finder.trashSentinel, true)
                    }
                }
            }
        }

        // ---- Content ----
        Rectangle {
            id: content
            anchors.top: toolbar.bottom
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.bottom: statusBar.top
            color: DesignTokens.bgRaised

            ListView {
                id: entriesView
                anchors.fill: parent
                anchors.margins: DesignTokens.spacingSmall
                clip: true
                spacing: 1
                model: finder.trashMode ? finder.trashEntries : finder.entries

                delegate: Rectangle {
                    id: rowItem
                    width: entriesView.width
                    height: 34
                    radius: DesignTokens.radiusSmall
                    color: rowItem.selected ? DesignTokens.accent
                                            : (rowMouse.containsMouse ? DesignTokens.bgBase
                                                                      : "transparent")

                    // Clicking selects the real path in browse mode and the trash record's
                    // content path in trash mode, so one selection value serves both.
                    readonly property string entryPath: finder.trashMode
                                                        ? modelData.contentPath : modelData.path
                    readonly property bool selected: finder.selectedPath === rowItem.entryPath

                    Rectangle {
                        id: kindChip
                        anchors.left: parent.left
                        anchors.leftMargin: DesignTokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 20
                        radius: 4
                        color: rowItem.selected ? "#ffffff22" : DesignTokens.bgBase
                        border.width: 1
                        border.color: DesignTokens.borderDefault

                        Text {
                            anchors.centerIn: parent
                            // A real extension or "DIR" is shown: no placeholder graphics are
                            // invented for file types the shell cannot resolve.
                            text: modelData.isDir ? "DIR" : finder.shortKind(modelData)
                            color: DesignTokens.textMuted
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        anchors.left: kindChip.right
                        anchors.leftMargin: DesignTokens.spacingSmall
                        anchors.right: sizeField.left
                        anchors.rightMargin: DesignTokens.spacingDefault
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !(rowItem.selected && finder.renaming)
                        text: modelData.name !== undefined ? modelData.name : ""
                        color: rowItem.selected ? "#ffffff" : DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        elide: Text.ElideMiddle
                    }

                    TextInput {
                        id: renameInput
                        anchors.left: kindChip.right
                        anchors.leftMargin: DesignTokens.spacingSmall
                        anchors.right: sizeField.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowItem.selected && finder.renaming
                        color: DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeBody
                        selectByMouse: true
                        autoScroll: true

                        // The text is seeded when the field appears rather than bound, so a
                        // keystroke cannot fight a binding.
                        onVisibleChanged: {
                            if (visible) {
                                text = finder.renameText
                                forceActiveFocus()
                                selectAll()
                            }
                        }
                        // onTextEdited only fires for user edits, never for programmatic ones.
                        onTextEdited: finder.renameText = text
                        onAccepted: finder.commitRename()
                        Keys.onEscapePressed: finder.renaming = false
                    }

                    Text {
                        id: sizeField
                        anchors.right: modifiedField.left
                        anchors.rightMargin: DesignTokens.spacingDefault
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70
                        horizontalAlignment: Text.AlignRight
                        text: modelData.size !== undefined && modelData.size > 0
                              ? finder.formatSize(modelData.size) : ""
                        color: rowItem.selected ? "#ffffffcc" : DesignTokens.textMuted
                        font.pixelSize: DesignTokens.fontSizeCaption
                    }

                    Text {
                        id: modifiedField
                        anchors.right: parent.right
                        anchors.rightMargin: DesignTokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        width: 140
                        horizontalAlignment: Text.AlignRight
                        text: modelData.modified !== undefined ? modelData.modified
                              : (modelData.deletedAt !== undefined ? modelData.deletedAt : "")
                        color: rowItem.selected ? "#ffffffcc" : DesignTokens.textMuted
                        font.pixelSize: DesignTokens.fontSizeCaption
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: finder.selectedPath = rowItem.entryPath
                        onDoubleClicked: {
                            if (finder.trashMode)
                                finder.restoreSelected()
                            else
                                finder.openEntry(modelData)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: (finder.trashMode ? finder.trashEntries.length : finder.entries.length) === 0
                text: finder.trashMode ? qsTr("The Trash is empty") : qsTr("This folder is empty")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeBody
            }
        }

        // ---- Status bar: the honest place for results and errors ----
        Rectangle {
            id: statusBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 26
            color: DesignTokens.bgBase

            Text {
                anchors.left: parent.left
                anchors.leftMargin: DesignTokens.spacingSmall
                anchors.right: showHiddenToggle.left
                anchors.rightMargin: DesignTokens.spacingDefault
                anchors.verticalCenter: parent.verticalCenter
                text: finder.message.length > 0
                      ? finder.message
                      : qsTr("%1 items").arg(finder.trashMode ? finder.trashEntries.length
                                                             : finder.entries.length)
                color: finder.messageIsError ? DesignTokens.statusError : DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
                elide: Text.ElideRight
            }

            Rectangle {
                id: showHiddenToggle
                anchors.right: parent.right
                anchors.rightMargin: DesignTokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                width: hiddenLabel.implicitWidth + DesignTokens.spacingSmall * 2
                height: 18
                radius: 4
                color: hiddenMouse.containsMouse ? DesignTokens.bgRaised : "transparent"

                Text {
                    id: hiddenLabel
                    anchors.centerIn: parent
                    text: finder.showHidden ? qsTr("Hiding hidden files") : qsTr("Show hidden files")
                    color: DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                }

                MouseArea {
                    id: hiddenMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        finder.showHidden = !finder.showHidden
                        finder.refresh()
                    }
                }
            }
        }
    }
}
