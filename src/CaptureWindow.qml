import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// The brain-dump box. Nothing here but a place to type: Super+N, type,
// Enter twice, gone.
ApplicationWindow {
    id: win
    width: 720
    height: 420
    visible: false
    // Hyprland floats and centers the window by this title.
    title: "lightswitch-capture"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    signal openLibrary()

    property bool wasActive: false

    function summon() {
        if (input.text !== notes.draft) input.text = notes.draft
        show()
        raise()
        requestActivate()
        input.forceActiveFocus()
        input.cursorPosition = input.length
    }

    // Let go: hide instantly and keep whatever is half-typed for next time.
    function release() {
        notes.draft = input.text
        notes.saveDraft()
        hide()
    }

    function commit() {
        if (notes.capture(input.text) < 0) return  // The error line says why; keep the text.
        input.text = ""
        release()
    }

    // Clicking away counts as letting go.
    onActiveChanged: {
        if (active) wasActive = true
        else if (wasActive && visible) { wasActive = false; release() }
    }

    Shortcut { sequence: "Esc"; onActivated: win.release() }
    Shortcut { sequence: "Ctrl+L"; onActivated: { win.release(); win.openLibrary() } }

    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            ScrollView {
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

            Label {
                visible: notes.error !== ""
                text: notes.error
                color: "#ff6b6b"
                font.pixelSize: 13
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("↵↵ save · Esc hide · Ctrl+L all notes")
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
    }
}
