import QtQuick
import Tahoe.Services 1.0
import "../tokens"

/* Project Tahoe X86 Spotlight.
 *
 * Unified search over installed applications, real files, and settings the shell can
 * actually change (SearchService). It is keyboard driven: type, move with the arrow keys,
 * open with Return, dismiss with Escape.
 *
 * Every result carries what the shell needs to act on it, and the panel reports the action
 * to the shell rather than pretending to perform it, so the shell can launch, open, or
 * navigate using the same code paths as the Dock.
 */
Item {
    id: spotlight

    property bool reduceMotion: false
    property var results: []
    property int selectedIndex: 0
    property string message: ""

    signal dismissed()
    signal applicationChosen(string desktopId)
    signal fileChosen(string path)
    signal settingChosen(string settingKey)

    function open() {
        visible = true
        queryInput.text = ""
        results = []
        selectedIndex = 0
        message = ""
        queryInput.forceActiveFocus()
    }

    function close() {
        visible = false
        dismissed()
    }

    function updateResults() {
        var query = queryInput.text
        results = query.trim().length > 0 ? SearchService.search(query, 12) : []
        selectedIndex = 0
        message = ""

        if (query.trim().length > 0 && results.length === 0)
            message = qsTr("Nothing matched \"%1\"").arg(query.trim())
    }

    function activateCurrent() {
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return

        var entry = results[selectedIndex]
        close()

        if (entry.type === "app")
            applicationChosen(entry.desktopId)
        else if (entry.type === "file")
            fileChosen(entry.path)
        else if (entry.type === "setting")
            settingChosen(entry.settingKey)
    }

    visible: false
    focus: visible

    Keys.onEscapePressed: close()
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onDownPressed: {
        if (results.length > 0)
            selectedIndex = Math.min(selectedIndex + 1, results.length - 1)
    }
    Keys.onUpPressed: {
        if (results.length > 0)
            selectedIndex = Math.max(selectedIndex - 1, 0)
    }

    // Clicking outside the panel dismisses, like every other search overlay.
    MouseArea {
        anchors.fill: parent
        onClicked: spotlight.close()
    }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.topMargin: DesignTokens.spacingLarge * 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(620, parent.width - DesignTokens.spacingLarge * 2)
        height: queryInput.implicitHeight + DesignTokens.spacingDefault * 2
                + (results.length > 0 || message.length > 0
                   ? Math.min(360, results.length * 44 + 24) : 0)
        radius: DesignTokens.radiusPanel
        color: DesignTokens.bgGlass
        border.width: 1
        border.color: DesignTokens.borderGlass

        Behavior on height {
            enabled: !spotlight.reduceMotion
            NumberAnimation { duration: DesignTokens.animationFast }
        }

        MouseArea {
            anchors.fill: parent
            // Swallow clicks so they do not reach the dismiss surface behind the panel.
            onClicked: queryInput.forceActiveFocus()
        }

        TextInput {
            id: queryInput
            anchors.top: parent.top
            anchors.topMargin: DesignTokens.spacingDefault
            anchors.left: parent.left
            anchors.leftMargin: DesignTokens.spacingDefault
            anchors.right: parent.right
            anchors.rightMargin: DesignTokens.spacingDefault
            color: DesignTokens.textPrimary
            font.pixelSize: 20
            selectByMouse: true
            onTextEdited: spotlight.updateResults()
            onAccepted: spotlight.activateCurrent()
        }

        Text {
            anchors.top: queryInput.bottom
            anchors.topMargin: DesignTokens.spacingSmall
            anchors.left: parent.left
            anchors.leftMargin: DesignTokens.spacingDefault
            visible: queryInput.text.length === 0
            text: qsTr("Search applications, files, and settings")
            color: DesignTokens.textMuted
            font.pixelSize: DesignTokens.fontSizeBody
        }

        Text {
            anchors.top: queryInput.bottom
            anchors.topMargin: DesignTokens.spacingDefault
            anchors.left: parent.left
            anchors.leftMargin: DesignTokens.spacingDefault
            anchors.right: parent.right
            anchors.rightMargin: DesignTokens.spacingDefault
            visible: spotlight.message.length > 0
            text: spotlight.message
            color: DesignTokens.textMuted
            font.pixelSize: DesignTokens.fontSizeBody
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            id: resultsView
            anchors.top: queryInput.bottom
            anchors.topMargin: DesignTokens.spacingDefault * 2
            anchors.left: parent.left
            anchors.leftMargin: DesignTokens.spacingSmall
            anchors.right: parent.right
            anchors.rightMargin: DesignTokens.spacingSmall
            anchors.bottom: parent.bottom
            anchors.bottomMargin: DesignTokens.spacingSmall
            clip: true
            model: spotlight.results
            spacing: 2

            delegate: Rectangle {
                width: resultsView.width
                height: 44
                radius: DesignTokens.radiusSmall
                color: index === spotlight.selectedIndex ? DesignTokens.accent
                                                         : (resultMouse.containsMouse
                                                            ? DesignTokens.bgRaised : "transparent")

                readonly property bool isSelected: index === spotlight.selectedIndex

                Text {
                    id: typeChip
                    anchors.left: parent.left
                    anchors.leftMargin: DesignTokens.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignLeft
                    // The result type is stated, so it is always clear what Return will do.
                    text: modelData.type === "app" ? qsTr("App")
                          : (modelData.type === "file" ? qsTr("File") : qsTr("Setting"))
                    color: isSelected ? "#ffffffcc" : DesignTokens.textMuted
                    font.pixelSize: DesignTokens.fontSizeCaption
                }

                Text {
                    anchors.left: typeChip.right
                    anchors.leftMargin: DesignTokens.spacingSmall
                    anchors.right: parent.right
                    anchors.rightMargin: DesignTokens.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title + (modelData.subtitle && modelData.subtitle.length > 0
                                             ? "  \u2014  " + modelData.subtitle : "")
                    color: isSelected ? "#ffffff" : DesignTokens.textPrimary
                    font.pixelSize: DesignTokens.fontSizeBody
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: resultMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: spotlight.selectedIndex = index
                    onClicked: {
                        spotlight.selectedIndex = index
                        spotlight.activateCurrent()
                    }
                }
            }
        }
    }
}
