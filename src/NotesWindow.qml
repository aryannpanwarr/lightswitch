import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Everything that was dumped, as a grid of cards (like Google Keep). Click a
// card to edit it; hover for done and delete.
ApplicationWindow {
    id: win
    width: 1100
    height: 760
    minimumWidth: 420
    minimumHeight: 360
    visible: false
    title: "Lightswitch"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent

    signal newNote()

    readonly property color ink: "#e8e8ea"
    readonly property color dim: "#7a7a80"
    readonly property color card: "#18181c"
    readonly property color edge: "#2a2a30"

    property string query: ""
    property var shown: []
    property int editingLine: -1
    property string toast: ""

    // Cards are dealt into columns left to right, newest first, so each
    // column keeps its own height (masonry).
    readonly property int columns: Math.max(1, Math.floor((grid.width + 16) / (240 + 16)))
    readonly property real cardWidth: (grid.width - (columns - 1) * 16) / columns

    function summon() {
        show()
        raise()
        requestActivate()
        take.forceActiveFocus()
    }

    function rebuild() {
        const q = query.trim().toLowerCase()
        shown = notes.items.filter(n => !n.done && (!q || n.text.toLowerCase().indexOf(q) >= 0))
    }

    function column(c) { return shown.filter((n, i) => i % columns === c) }

    function say(message) { toast = message; toastTimer.restart() }

    onQueryChanged: rebuild()
    Component.onCompleted: rebuild()
    Connections { target: notes; function onChanged() { win.rebuild() } }
    Timer { id: toastTimer; interval: 4000; onTriggered: win.toast = "" }

    Shortcut { sequences: [StandardKey.Undo]; enabled: win.editingLine < 0 && notes.canUndo; onActivated: { notes.undo(); win.toast = "" } }
    Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }

    // Top bar: name and search
    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        height: 68
        color: win.color
        z: 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 24

            Row {
                spacing: 10
                Rectangle {
                    width: 30; height: 30; radius: 7
                    color: theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 10; height: 16; radius: 2; anchors.centerIn: parent; color: "transparent"; border.width: 2; border.color: theme.accentForeground }
                }
                Label { text: "Lightswitch"; font.pixelSize: 20; color: win.ink; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 720
                implicitHeight: 46
                radius: 8
                color: search.activeFocus ? "#202026" : "#17171b"
                Label {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌕"
                    font.pixelSize: 20
                    color: win.dim
                }
                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 16
                    color: win.ink
                    selectionColor: theme.accent
                    clip: true
                    onTextChanged: win.query = text
                    Keys.onEscapePressed: { text = ""; take.forceActiveFocus() }
                    Label { visible: !search.text; text: qsTr("Search"); font.pixelSize: 16; color: win.dim }
                }
            }
            Item { Layout.fillWidth: true }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1e1e22" }
    }

    Flickable {
        id: scroller
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        contentHeight: content.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: content
            width: Math.min(scroller.width - 56, 1240)
            x: (scroller.width - width) / 2
            topPadding: 28
            spacing: 32

            // "Take a note…": type and press Enter.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, 600)
                height: Math.max(48, take.implicitHeight + 26)
                radius: 8
                color: win.card
                border.color: take.activeFocus ? "#3a3a42" : win.edge
                TextEdit {
                    id: take
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    wrapMode: TextEdit.Wrap
                    font.pixelSize: 16
                    color: win.ink
                    selectionColor: theme.accent
                    Label { visible: !take.text; text: qsTr("Take a note…"); font.pixelSize: 16; color: win.dim }
                    Keys.onPressed: (event) => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            event.accepted = true
                            if (text.trim()) notes.capture(text.replace(/\n/g, " "))
                            text = ""
                        }
                    }
                }
            }

            // The cards
            Row {
                id: grid
                width: parent.width
                spacing: 16
                Repeater {
                    model: win.columns
                    delegate: Column {
                        required property int index
                        width: win.cardWidth
                        spacing: 16
                        Repeater {
                            model: win.column(index)
                            delegate: NoteCard {
                                width: win.cardWidth
                                onOpen: (line) => win.editingLine = line
                                onDone: (line) => { notes.setDone(line, true); win.say(qsTr("Marked done")) }
                                onDiscard: (line) => { notes.remove(line); win.say(qsTr("Note deleted")) }
                            }
                        }
                    }
                }
            }

            Column {
                visible: win.shown.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 80
                spacing: 10
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.query ? qsTr("No matching notes") : qsTr("Notes you dump appear here")
                    font.pixelSize: 20
                    color: win.dim
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !win.query
                    text: qsTr("Press Super + N anywhere")
                    font.pixelSize: 14
                    color: "#4a4a50"
                }
            }
        }
    }

    // Toast with undo, bottom left like Keep.
    Rectangle {
        visible: win.toast !== ""
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        width: toastRow.implicitWidth + 40
        height: 48
        radius: 6
        color: "#2a2a30"
        z: 4
        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 28
            Label { text: win.toast; color: win.ink; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            Label {
                text: qsTr("Undo")
                color: theme.accent
                font.pixelSize: 14
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: { notes.undo(); win.toast = "" } }
            }
        }
    }

    // Editing a note: the card opens large in the middle; closing saves.
    Rectangle {
        id: editLayer
        anchors.fill: parent
        visible: win.editingLine >= 0
        color: "#b0000000"
        z: 5

        function close() {
            if (win.editingLine < 0) return
            const line = win.editingLine, text = editor.text
            win.editingLine = -1
            take.forceActiveFocus()
            const item = notes.items.find(n => n.line === line)
            if (item && item.text !== text.replace(/\n/g, " ").trim()) notes.edit(line, text)
        }

        onVisibleChanged: if (visible) {
            const item = notes.items.find(n => n.line === win.editingLine)
            editor.text = item ? item.text : ""
            Qt.callLater(() => { editor.forceActiveFocus(); editor.cursorPosition = editor.length })
        }

        MouseArea { anchors.fill: parent; onClicked: editLayer.close() }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 600)
            height: Math.min(parent.height - 48, editor.implicitHeight + 90)
            radius: 10
            color: win.card
            border.color: win.edge
            MouseArea { anchors.fill: parent }  // Clicks inside don't close it.

            TextEdit {
                id: editor
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                wrapMode: TextEdit.Wrap
                font.pixelSize: 18
                color: win.ink
                selectionColor: theme.accent
                Keys.onEscapePressed: editLayer.close()
                Keys.onPressed: (event) => {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                        event.accepted = true
                        editLayer.close()
                    }
                }
            }

            Label {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                text: qsTr("Close")
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: win.ink
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: editLayer.close() }
            }
        }
    }
}
