import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 720
    height: 420
    visible: startVisible
    title: "Lightswitch"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    // "capture" is the brain-dump box; "later" is the list of open notes.
    property string mode: startMode
    property bool helpVisible: false
    property bool wasActive: false

    Component.onCompleted: if (visible) summon(startMode)

    function summon(which) {
        mode = which || "capture"
        helpVisible = false
        if (input.text !== notes.draft) input.text = notes.draft
        show()
        raise()
        requestActivate()
        focusMode()
    }

    function focusMode() {
        if (mode === "capture") {
            input.forceActiveFocus()
            input.cursorPosition = input.length
        } else {
            list.forceActiveFocus()
            list.currentIndex = Math.min(Math.max(list.currentIndex, 0), list.count - 1)
        }
    }

    // Let go: hide instantly and keep whatever is half-typed for next time.
    function release() {
        notes.draft = input.text
        notes.saveDraft()
        hide()
    }

    function commit() {
        const saved = notes.capture(input.text)
        if (saved < 0) return  // The error line says why; keep the text.
        input.text = ""
        release()
    }

    Connections {
        target: ipc
        function onToggleRequested() { if (win.visible && win.active) win.release(); else win.summon("capture") }
        function onShowRequested() { win.summon("capture") }
        function onLaterRequested() { win.summon("later") }
    }

    // Clicking away counts as letting go.
    onActiveChanged: {
        if (active) wasActive = true
        else if (wasActive && visible) { wasActive = false; release() }
    }

    Shortcut { sequence: "Esc"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible ? win.helpVisible = false : win.release() }
    Shortcut { sequence: "Tab"; context: Qt.ApplicationShortcut; onActivated: { win.mode = win.mode === "capture" ? "later" : "capture"; win.focusMode() } }
    Shortcut { sequence: "F1"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequences: [StandardKey.Undo]; context: Qt.ApplicationShortcut; enabled: win.mode === "later"; onActivated: notes.undo() }
    Shortcut { sequence: "Ctrl+O"; context: Qt.ApplicationShortcut; onActivated: { notes.openFile(); win.release() } }

    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            // Capture
            ScrollView {
                visible: win.mode === "capture"
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextArea {
                    id: input
                    placeholderText: qsTr("Dump it here. Enter twice to let go.")
                    wrapMode: TextArea.Wrap
                    font.pixelSize: 22
                    color: "#ececec"
                    placeholderTextColor: "#5a5a60"
                    selectionColor: theme.accent
                    selectedTextColor: theme.accentForeground
                    background: null
                    padding: 0

                    // One Enter is a new note on a new line; Enter on an empty
                    // line (so, Enter twice) saves everything and hides.
                    Keys.onPressed: (event) => {
                        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return
                        if (event.modifiers & Qt.ShiftModifier) return
                        event.accepted = true
                        if (text.trim() === "") { text = ""; win.release(); return }
                        const before = text.substring(0, cursorPosition)
                        if (before.length === 0 || before.endsWith("\n")) win.commit()
                        else insert(cursorPosition, "\n")
                    }
                }
            }

            // Later
            ListView {
                id: list
                visible: win.mode === "later"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: notes.open
                spacing: 2
                keyNavigationEnabled: true
                highlightMoveDuration: 0

                function done() {
                    if (currentIndex < 0 || currentIndex >= count) return
                    const keep = currentIndex
                    notes.markDone(model[currentIndex].line)
                    currentIndex = Math.min(keep, count - 1)
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_J) { incrementCurrentIndex(); event.accepted = true }
                    else if (event.key === Qt.Key_K) { decrementCurrentIndex(); event.accepted = true }
                    else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                             || event.key === Qt.Key_X || event.key === Qt.Key_D || event.key === Qt.Key_Delete) {
                        done(); event.accepted = true
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: row.implicitHeight + 16
                    radius: Math.min(4, theme.radius)
                    color: ListView.isCurrentItem ? "#1c1c20" : "transparent"
                    border.width: ListView.isCurrentItem ? 1 : 0
                    border.color: theme.accent

                    RowLayout {
                        id: row
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 14
                        Label {
                            text: modelData.when
                            color: "#6a6a70"
                            font.pixelSize: 13
                            Layout.preferredWidth: 64
                        }
                        Label {
                            text: modelData.text
                            color: "#ececec"
                            font.pixelSize: 17
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: list.currentIndex = index
                        onDoubleClicked: { list.currentIndex = index; list.done() }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: qsTr("Nothing waiting. Clear head.")
                    color: "#5a5a60"
                    font.pixelSize: 17
                }
            }

            Label {
                visible: notes.error !== ""
                text: notes.error
                color: "#ff6b6b"
                font.pixelSize: 13
            }

            // Footer: the only hints there are, always visible.
            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                Label {
                    text: win.mode === "capture"
                          ? qsTr("↵↵ save · Esc hide · Tab later")
                          : qsTr("Space done · Ctrl+Z undo · Tab write · Esc hide")
                    color: "#5a5a60"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Label {
                    text: qsTr("%n for later", "", notes.openCount)
                    color: notes.openCount > 0 ? theme.accent : "#5a5a60"
                    font.pixelSize: 12
                }
            }
        }

        // Shortcut overlay (F1, since ? is something you might type).
        Rectangle {
            anchors.fill: parent
            visible: win.helpVisible
            color: "#ee0e0e10"
            Column {
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: [
                        [qsTr("Super + N"), qsTr("Show / hide")],
                        [qsTr("Enter"), qsTr("Next note")],
                        [qsTr("Enter twice"), qsTr("Save and hide")],
                        [qsTr("Shift + Enter"), qsTr("Line break")],
                        [qsTr("Esc"), qsTr("Hide, keep draft")],
                        [qsTr("Tab"), qsTr("Switch write / later")],
                        [qsTr("Space, Enter, X"), qsTr("Mark done (later)")],
                        [qsTr("J / K"), qsTr("Move (later)")],
                        [qsTr("Ctrl + Z"), qsTr("Undo done")],
                        [qsTr("Ctrl + O"), qsTr("Open the notes file")]
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: 28
                        Label { text: modelData[0]; color: theme.accent; font.pixelSize: 14; width: 150 }
                        Label { text: modelData[1]; color: "#ececec"; font.pixelSize: 14 }
                    }
                }
            }
        }
    }
}
