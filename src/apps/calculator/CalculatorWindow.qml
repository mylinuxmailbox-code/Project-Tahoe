import QtQuick
import "../../shared/tokens"

/* Project Tahoe X86 Calculator.
 *
 * Local arithmetic only: no network, no files, and nothing written to disk. Division by zero
 * and out-of-range results are shown as errors and never as a number.
 */
Item {
    id: calc

    // Injected by the window layer.
    property var windowFrame: null
    property bool reduceMotion: false

    property string display: "0"
    property real accumulator: 0
    property string pendingOp: ""
    property bool freshInput: true
    property bool errorState: false

    readonly property int keyGap: 8
    readonly property int displayHeight: 84

    // Keys in reading order. action is what press() does; arg is the digit or operator.
    readonly property var keys: [
        { "name": qsTr("Clear"), "label": "C", "action": "clear", "arg": "" },
        { "name": qsTr("Toggle sign"), "label": "\u00b1", "action": "sign", "arg": "" },
        { "name": qsTr("Delete"), "label": "DEL", "action": "backspace", "arg": "" },
        { "name": qsTr("Divide"), "label": "\u00f7", "action": "op", "arg": "/" },
        { "name": "7", "label": "7", "action": "digit", "arg": "7" },
        { "name": "8", "label": "8", "action": "digit", "arg": "8" },
        { "name": "9", "label": "9", "action": "digit", "arg": "9" },
        { "name": qsTr("Multiply"), "label": "\u00d7", "action": "op", "arg": "*" },
        { "name": "4", "label": "4", "action": "digit", "arg": "4" },
        { "name": "5", "label": "5", "action": "digit", "arg": "5" },
        { "name": "6", "label": "6", "action": "digit", "arg": "6" },
        { "name": qsTr("Subtract"), "label": "\u2212", "action": "op", "arg": "-" },
        { "name": "1", "label": "1", "action": "digit", "arg": "1" },
        { "name": "2", "label": "2", "action": "digit", "arg": "2" },
        { "name": "3", "label": "3", "action": "digit", "arg": "3" },
        { "name": qsTr("Add"), "label": "+", "action": "op", "arg": "+" },
        { "name": "0", "label": "0", "action": "digit", "arg": "0" },
        { "name": qsTr("Decimal point"), "label": ".", "action": "dot", "arg": "" },
        { "name": qsTr("Equals"), "label": "=", "action": "equals", "arg": "" }
    ]

    function clearAll() {
        display = "0"
        accumulator = 0
        pendingOp = ""
        freshInput = true
        errorState = false
    }

    function fail(reason) {
        display = reason
        accumulator = 0
        pendingOp = ""
        freshInput = true
        errorState = true
    }

    // Shows at most 12 significant digits, so the display never overflows its row.
    function formatResult(value) {
        return String(Number(value.toPrecision(12)))
    }

    function currentValue() {
        return Number(display)
    }

    function apply(left, op, right) {
        if (op === "+") return left + right
        if (op === "-") return left - right
        if (op === "*") return left * right
        if (op === "/") return right === 0 ? NaN : left / right
        return right
    }

    // Returns false (and shows the error) when the result is not a finite number.
    function settle(result) {
        if (isNaN(result))
            return false
        if (!isFinite(result)) {
            fail(qsTr("Result too large"))
            return false
        }
        return true
    }

    function inputDigit(digit) {
        if (errorState)
            clearAll()
        if (freshInput) {
            display = digit
            freshInput = false
            return
        }
        if (display === "0") {
            display = digit
            return
        }
        // A double's reliable precision is about 15 digits; refuse more than that.
        if (display.replace("-", "").replace(".", "").length >= 15)
            return
        display = display + digit
    }

    function inputDot() {
        if (errorState)
            clearAll()
        if (freshInput) {
            display = "0."
            freshInput = false
            return
        }
        if (display.indexOf(".") < 0)
            display = display + "."
    }

    function backspace() {
        if (errorState || freshInput)
            return
        if (display.length <= 1 || (display.length === 2 && display.charAt(0) === "-"))
            display = "0"
        else
            display = display.substring(0, display.length - 1)
    }

    function toggleSign() {
        if (errorState || display === "0")
            return
        display = display.charAt(0) === "-" ? display.substring(1) : "-" + display
    }

    function setOperator(op) {
        if (errorState)
            return

        if (pendingOp !== "" && !freshInput) {
            // Chained operation: settle the pending one first, so 2 + 3 * 4 reads left to right.
            var partial = apply(accumulator, pendingOp, currentValue())
            if (!settle(partial)) {
                if (!errorState)
                    fail(qsTr("Cannot divide by zero"))
                return
            }
            accumulator = partial
            display = formatResult(partial)
        } else if (pendingOp === "") {
            accumulator = currentValue()
        }

        pendingOp = op
        freshInput = true
    }

    function equals() {
        if (errorState || pendingOp === "")
            return

        var result = apply(accumulator, pendingOp, currentValue())
        if (!settle(result)) {
            if (!errorState)
                fail(qsTr("Cannot divide by zero"))
            return
        }

        display = formatResult(result)
        accumulator = result
        pendingOp = ""
        freshInput = true
    }

    function press(action, arg) {
        if (action === "digit") inputDigit(arg)
        else if (action === "dot") inputDot()
        else if (action === "op") setOperator(arg)
        else if (action === "equals") equals()
        else if (action === "clear") clearAll()
        else if (action === "sign") toggleSign()
        else if (action === "backspace") backspace()
    }

    // Keyboard entry, the way a person expects from a calculator.
    focus: true
    Keys.onPressed: function (event) {
        var text = event.text
        var handled = true
        if (text.length === 1 && text >= "0" && text <= "9")
            inputDigit(text)
        else if (text === "." || text === ",")
            inputDot()
        else if (text === "+" || text === "-" || text === "*" || text === "/")
            setOperator(text)
        else if (text === "=" || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            equals()
        else if (event.key === Qt.Key_Backspace)
            backspace()
        else if (event.key === Qt.Key_Escape || text === "c" || text === "C")
            clearAll()
        else
            handled = false
        event.accepted = handled
    }

    Rectangle {
        anchors.fill: parent
        color: DesignTokens.bgPanel

        // ---- Display ----
        Rectangle {
            id: displayArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: DesignTokens.spacingDefault
            height: calc.displayHeight
            radius: DesignTokens.radiusDefault
            color: DesignTokens.bgBase

            Text {
                id: displayText
                anchors.right: parent.right
                anchors.rightMargin: DesignTokens.spacingDefault
                anchors.bottom: parent.bottom
                anchors.bottomMargin: DesignTokens.spacingSmall
                anchors.left: parent.left
                anchors.leftMargin: DesignTokens.spacingDefault
                horizontalAlignment: Text.AlignRight
                text: calc.display
                color: calc.errorState ? DesignTokens.statusError : DesignTokens.textPrimary
                font.pixelSize: calc.errorState ? DesignTokens.fontSizeBody : DesignTokens.fontSizeTitle
                elide: Text.ElideLeft
                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("Display")
                Accessible.description: calc.display
            }
        }

        // ---- Keys ----
        Grid {
            id: keyGrid
            anchors.top: displayArea.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: DesignTokens.spacingDefault
            anchors.topMargin: DesignTokens.spacingSmall
            columns: 4
            spacing: calc.keyGap

            Repeater {
                model: calc.keys

                delegate: Rectangle {
                    id: key
                    width: (keyGrid.width - calc.keyGap * 3) / 4
                    height: (keyGrid.height - calc.keyGap * 4) / 5
                    radius: DesignTokens.radiusDefault
                    // Operators and equals read as the primary actions; everything else is neutral.
                    readonly property bool isOperator: modelData.action === "op" || modelData.action === "equals"
                    color: keyMouse.pressed ? DesignTokens.bgRaised
                           : (key.isOperator ? DesignTokens.accent : DesignTokens.bgRaised)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: key.isOperator ? "#ffffff" : DesignTokens.textPrimary
                        font.pixelSize: DesignTokens.fontSizeTitle
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name

                    MouseArea {
                        id: keyMouse
                        anchors.fill: parent
                        onClicked: calc.press(modelData.action, modelData.arg)
                    }
                }
            }
        }
    }
}
