import QtQuick
import Tahoe.Services 1.0
import "../../shared/tokens"

/* Project Tahoe X86 Text Editor.
 *
 * Plain text and Markdown are both edited as plain text: there is no Markdown preview yet.
 * Open and save go through FileService, so a file is only ever read or written as UTF-8 text,
 * binary files are refused, and a save replaces the file atomically.
 *
 * Two things are deliberately not silent:
 *   - Save As never overwrites a different existing file.
 *   - Opening or creating a new document with unsaved changes asks twice before discarding.
 *
 * There is no file chooser yet: paths are typed into the path field.
 */
Item {
    id: editor

    // Injected by the window layer.
    property var windowFrame: null
    property bool reduceMotion: false

    readonly property int maxBytes: 5 * 1024 * 1024

    property string filePath: ""
    property string savedText: ""
    readonly property bool dirty: docArea.text !== savedText
    readonly property string documentName: filePath.length > 0 ? fileNameOf(filePath) : qsTr("Untitled")

    property bool discardArmed: false
    property string message: ""
    property bool messageIsError: false

    function report(text, isError) {
        message = text
        messageIsError = isError === true
    }

    function fileNameOf(path) {
        return path.substring(path.lastIndexOf("/") + 1)
    }

    function existsAt(path) {
        var info = FileService.stat(path)
        return info !== undefined && info !== null && info.name !== undefined
    }

    // First request with unsaved changes is refused and armed; the second request goes ahead.
    // Nothing is discarded on the first press.
    function allowDiscard(action) {
        if (!dirty || discardArmed) {
            discardArmed = false
            return true
        }
        discardArmed = true
        report(qsTr("Unsaved changes. Press %1 again to discard them, or save first.").arg(action), true)
        return false
    }

    function newDocument() {
        if (!allowDiscard(qsTr("New")))
            return
        filePath = ""
        savedText = ""
        docArea.text = ""
        pathField.text = ""
        report(qsTr("New document"), false)
    }

    function openPath(path) {
        var target = path.trim()
        if (target.length === 0) {
            report(qsTr("Type a file path first"), true)
            return
        }
        if (!allowDiscard(qsTr("Open")))
            return

        var result = FileService.readText(target, maxBytes)
        if (!result.ok) {
            report(result.error, true)
            return
        }

        filePath = target
        savedText = result.text
        docArea.text = result.text
        pathField.text = target
        report(qsTr("Opened %1").arg(fileNameOf(target)), false)
    }

    function save() {
        if (filePath.length === 0) {
            report(qsTr("Type a file name in the path field, then press Save As"), true)
            return
        }

        var result = FileService.writeText(filePath, docArea.text)
        if (!result.ok) {
            report(result.error, true)
            return
        }

        savedText = docArea.text
        report(result.message, false)
    }

    function saveAs() {
        var target = pathField.text.trim()
        if (target.length === 0) {
            report(qsTr("Type a file path first"), true)
            return
        }
        if (FileService.isDirectory(target)) {
            report(qsTr("That path is a folder"), true)
            return
        }
        // Saving over a different file that already exists needs the user to choose another name.
        if (target !== filePath && existsAt(target)) {
            report(qsTr("'%1' already exists. Choose another name.").arg(fileNameOf(target)), true)
            return
        }

        var result = FileService.writeText(target, docArea.text)
        if (!result.ok) {
            report(result.error, true)
            return
        }

        filePath = target
        savedText = docArea.text
        report(result.message, false)
    }

    Component.onCompleted: docArea.forceActiveFocus()

    // Editor shortcuts. Typing goes to the document first; these only fire for Ctrl chords the
    // text area does not use.
    Keys.onPressed: function (event) {
        if (!(event.modifiers & Qt.ControlModifier))
            return
        if (event.key === Qt.Key_S) {
            if (event.modifiers & Qt.ShiftModifier)
                editor.saveAs()
            else
                editor.save()
        } else if (event.key === Qt.Key_N) {
            editor.newDocument()
        } else if (event.key === Qt.Key_O) {
            pathField.forceActiveFocus()
        } else {
            return
        }
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
                id: actions
                anchors.left: parent.left
                anchors.leftMargin: DesignTokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: DesignTokens.spacingTiny

                Repeater {
                    model: [
                        { "label": qsTr("New"), "action": "new" },
                        { "label": qsTr("Open"), "action": "open" },
                        { "label": qsTr("Save"), "action": "save" },
                        { "label": qsTr("Save As"), "action": "saveas" }
                    ]

                    delegate: Rectangle {
                        width: actionLabel.implicitWidth + DesignTokens.spacingSmall * 2
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

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.label

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.action === "new")
                                    editor.newDocument()
                                else if (modelData.action === "open")
                                    editor.openPath(pathField.text)
                                else if (modelData.action === "save")
                                    editor.save()
                                else
                                    editor.saveAs()
                            }
                        }
                    }
                }
            }

            // Path field: the only way to choose a file until a file chooser exists.
            Rectangle {
                anchors.left: actions.right
                anchors.leftMargin: DesignTokens.spacingDefault
                anchors.right: parent.right
                anchors.rightMargin: DesignTokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                radius: DesignTokens.radiusSmall
                color: DesignTokens.bgRaised
                border.width: pathField.activeFocus ? 1 : 0
                border.color: DesignTokens.accent

                TextInput {
                    id: pathField
                    anchors.fill: parent
                    anchors.leftMargin: DesignTokens.spacingSmall
                    anchors.rightMargin: DesignTokens.spacingSmall
                    verticalAlignment: TextInput.AlignVCenter
                    color: DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeCaption
                    selectByMouse: true
                    clip: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: qsTr("File path")
                    // Enter opens the path; Save As is a button so a path is never saved by accident.
                    onAccepted: editor.openPath(text)
                }

                Text {
                    anchors.left: pathField.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pathField.text.length === 0 && !pathField.activeFocus
                    text: qsTr("Type a file path, for example ~/Documents/notes.txt")
                    color: DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                }
            }
        }

        // ---- Document ----
        Rectangle {
            id: page
            anchors.top: toolbar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: statusBar.top
            color: DesignTokens.bgRaised

            Flickable {
                id: scroller
                anchors.fill: parent
                anchors.margins: DesignTokens.spacingDefault
                clip: true
                contentWidth: width
                contentHeight: Math.max(height, docArea.contentHeight)
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: docArea
                    width: scroller.width
                    height: Math.max(scroller.height, contentHeight)
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    font.family: "monospace"
                    font.pixelSize: DesignTokens.fontSizeBody
                    color: DesignTokens.textPrimary
                    selectByMouse: true
                    persistentSelection: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: qsTr("Document text")
                    Accessible.description: editor.documentName
                }
            }

            Text {
                anchors.centerIn: parent
                visible: docArea.text.length === 0 && editor.filePath.length === 0
                text: qsTr("Start typing, or open a file by its path above")
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
                anchors.right: stateLabel.left
                anchors.rightMargin: DesignTokens.spacingDefault
                anchors.verticalCenter: parent.verticalCenter
                text: editor.message
                color: editor.messageIsError ? DesignTokens.statusError : DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
                elide: Text.ElideRight
            }

            Text {
                id: stateLabel
                anchors.right: parent.right
                anchors.rightMargin: DesignTokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                text: editor.dirty ? qsTr("Edited") : qsTr("Saved")
                color: DesignTokens.textMuted
                font.pixelSize: DesignTokens.fontSizeCaption
            }
        }
    }
}
