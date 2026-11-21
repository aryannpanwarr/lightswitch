import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Everything that was dumped, grouped by day, to go through later.
ApplicationWindow {
    id: win
    width: 1000
    height: 700
    minimumWidth: 520
    minimumHeight: 380
    visible: false
    title: "Lightswitch"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    signal newNote()

    // "open", "done", or "all".
    property string filter: "open"
    property string query: ""
    property int editingLine: -1
    property bool helpVisible: false
    property string toast: ""
    property bool toastUndo: false

    readonly property color text: "#ececec"
    readonly property color dim: "#6a6a70"
    readonly property color faint: "#3a3a40"
    readonly property color raised: "#16161a"

    function summon() {
        show()
        raise()
        requestActivate()
        list.forceActiveFocus()
    }

    function rebuild() {
        const keep = list.currentIndex
        const q = query.trim().toLowerCase()
        shown.clear()
        for (const item of notes.items) {
            if (filter === "open" && item.done) continue
            if (filter === "done" && !item.done) continue
            if (q && item.text.toLowerCase().indexOf(q) < 0) continue
            shown.append(item)
        }
        list.currentIndex = shown.count === 0 ? -1 : Math.min(Math.max(keep, 0), shown.count - 1)
    }

    function current() { return list.currentIndex >= 0 ? shown.get(list.currentIndex) : null }

    function say(message, undoable) { toast = message; toastUndo = undoable !== false; toastTimer.restart() }

    function toggleCurrent() {
        const item = current()
        if (!item) return
        const wasDone = item.done
        notes.setDone(item.line, !wasDone)
        say(wasDone ? qsTr("Back to open") : qsTr("Done"))
    }

    function removeCurrent() {
        const item = current()
        if (!item) return
        notes.remove(item.line)
        say(qsTr("Deleted"))
    }

    function setFilter(which) { filter = which; list.forceActiveFocus() }

    onFilterChanged: rebuild()
    onQueryChanged: rebuild()
    Component.onCompleted: rebuild()
    Connections { target: notes; function onChanged() { win.rebuild() } }

    ListModel { id: shown }
    Timer { id: toastTimer; interval: 3500; onTriggered: win.toast = "" }

    Shortcut { sequences: [StandardKey.Undo]; enabled: notes.canUndo && win.editingLine < 0; onActivated: { notes.undo(); win.say(qsTr("Undone"), false) } }
    Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+N"; onActivated: win.newNote() }
    Shortcut { sequence: "Ctrl+O"; onActivated: notes.openFile() }

    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 40
            anchors.rightMargin: 40
            anchors.topMargin: 32
            anchors.bottomMargin: 18
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ColumnLayout {
                    spacing: 4
                    Label {
                        text: qsTr("Notes")
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        color: win.text
                    }
                    Label {
                        text: qsTr("%1 open · %2 done").arg(notes.openCount).arg(notes.doneCount)
                        font.pixelSize: 13
                        color: win.dim
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: newLabel.implicitWidth + 32
                    implicitHeight: 38
                    radius: Math.min(6, theme.radius)
                    color: newMouse.containsMouse ? Qt.lighter(theme.accent, 1.1) : theme.accent
                    Label {
                        id: newLabel
                        anchors.centerIn: parent
                        text: qsTr("+  New note")
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: theme.accentForeground
                    }
                    MouseArea { id: newMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.newNote() }
                }
            }

            // Filters and search
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 24
                spacing: 4

                Repeater {
                    model: [
                        { key: "open", label: qsTr("Open"), count: notes.openCount },
                        { key: "done", label: qsTr("Done"), count: notes.doneCount },
                        { key: "all", label: qsTr("All"), count: notes.openCount + notes.doneCount }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected: win.filter === modelData.key
                        implicitWidth: tabRow.implicitWidth + 24
                        implicitHeight: 34
                        radius: Math.min(4, theme.radius)
                        color: selected ? win.raised : tabMouse.containsMouse ? "#121215" : "transparent"
                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 7
                            Label {
                                text: modelData.label
                                font.pixelSize: 14
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? win.text : win.dim
                            }
                            Label {
                                text: modelData.count
                                font.pixelSize: 12
                                color: selected ? theme.accent : win.faint
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Rectangle {
                            visible: selected
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 16
                            height: 2
                            color: theme.accent
                        }
                        MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; onClicked: win.setFilter(modelData.key) }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 260
                    implicitHeight: 34
                    radius: Math.min(6, theme.radius)
                    color: win.raised
                    border.width: 1
                    border.color: search.activeFocus ? theme.accent : "#1f1f24"
                    Label {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        font.pixelSize: 16
                        color: win.dim
                    }
                    // A plain TextInput: the Material TextField floats its
                    // placeholder up as a label, which collides in a box this small.
                    TextInput {
                        id: search
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: win.text
                        selectionColor: theme.accent
                        selectedTextColor: theme.accentForeground
                        font.pixelSize: 14
                        clip: true
                        Label {
                            visible: search.text === ""
                            text: qsTr("Search   /")
                            color: win.faint
                            font.pixelSize: 14
                        }
                        text: win.query
                        onTextChanged: win.query = text
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) { text = ""; list.forceActiveFocus(); event.accepted = true }
                            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                list.forceActiveFocus(); event.accepted = true
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; height: 1; color: "#1c1c20" }

            // The notes
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 4
                clip: true
                model: shown
                focus: true
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                section.property: "day"
                section.delegate: Label {
                    required property string section
                    width: ListView.view.width
                    topPadding: 22
                    bottomPadding: 8
                    leftPadding: 12
                    text: section.toUpperCase()
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    color: win.dim
                }

                Keys.onPressed: (event) => {
                    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
                    const k = event.key
                    if (k === Qt.Key_J) incrementCurrentIndex()
                    else if (k === Qt.Key_K) decrementCurrentIndex()
                    else if (k === Qt.Key_Space || k === Qt.Key_X) win.toggleCurrent()
                    else if (k === Qt.Key_E || k === Qt.Key_Return || k === Qt.Key_Enter) {
                        const item = win.current(); if (item) win.editingLine = item.line
                    }
                    else if (k === Qt.Key_D || k === Qt.Key_Delete || k === Qt.Key_Backspace) win.removeCurrent()
                    else if (k === Qt.Key_Slash) search.forceActiveFocus()
                    else if (k === Qt.Key_N) win.newNote()
                    else if (k === Qt.Key_1) win.setFilter("open")
                    else if (k === Qt.Key_2) win.setFilter("done")
                    else if (k === Qt.Key_3) win.setFilter("all")
                    else if (k === Qt.Key_Question) win.helpVisible = !win.helpVisible
                    else if (k === Qt.Key_Escape) {
                        if (win.helpVisible) win.helpVisible = false
                        else if (win.query !== "") search.text = ""
                        else win.hide()
                    }
                    else return
                    event.accepted = true
                }

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property int line
                    required property string text
                    required property string time
                    required property bool done
                    readonly property bool isCurrent: ListView.isCurrentItem && list.activeFocus
                    readonly property bool editing: win.editingLine === line

                    width: ListView.view.width
                    height: Math.max(48, body.implicitHeight + 24)
                    radius: Math.min(4, theme.radius)
                    color: isCurrent ? "#1a1a1f" : rowMouse.containsMouse ? "#131316" : "transparent"

                    Rectangle {
                        visible: row.isCurrent
                        width: 3
                        height: parent.height - 16
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 2
                        color: theme.accent
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { list.currentIndex = row.index; list.forceActiveFocus() }
                        onDoubleClicked: win.editingLine = row.line
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14

                        // Check circle
                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 10
                            color: row.done ? theme.accent : "transparent"
                            border.width: row.done ? 0 : 2
                            border.color: checkMouse.containsMouse ? theme.accent : "#4a4a50"
                            Label {
                                anchors.centerIn: parent
                                visible: row.done
                                text: "✓"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: theme.accentForeground
                            }
                            MouseArea {
                                id: checkMouse
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { list.currentIndex = row.index; win.toggleCurrent() }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: body.implicitHeight

                            Label {
                                id: body
                                visible: !row.editing
                                width: parent.width
                                text: row.text
                                wrapMode: Text.Wrap
                                font.pixelSize: 16
                                font.strikeout: row.done
                                color: row.done ? win.dim : win.text
                            }

                            TextField {
                                id: editor
                                visible: row.editing
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 16
                                // Deferred: the list hands focus back to its current row first.
                                onVisibleChanged: if (visible) { text = row.text; Qt.callLater(() => { forceActiveFocus(); cursorPosition = length }) }
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        // Saving rebuilds the list and destroys this row, so it goes last.
                                        const line = row.line, value = text
                                        event.accepted = true
                                        win.editingLine = -1; list.forceActiveFocus()
                                        notes.edit(line, value)
                                    } else if (event.key === Qt.Key_Escape) {
                                        win.editingLine = -1; list.forceActiveFocus(); event.accepted = true
                                    }
                                }
                                onActiveFocusChanged: if (!activeFocus && row.editing) win.editingLine = -1
                            }
                        }

                        Label {
                            text: row.time
                            font.pixelSize: 12
                            color: win.dim
                            visible: !row.editing
                        }

                        // Delete, on hover
                        Label {
                            text: "×"
                            font.pixelSize: 20
                            color: deleteMouse.containsMouse ? "#ff6b6b" : win.dim
                            opacity: rowMouse.containsMouse || deleteMouse.containsMouse ? 1 : 0
                            MouseArea {
                                id: deleteMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { list.currentIndex = row.index; win.removeCurrent() }
                            }
                        }
                    }
                }

                // Empty states
                Column {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    spacing: 8
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.query !== "" ? qsTr("No notes match “%1”").arg(win.query)
                            : win.filter === "done" ? qsTr("Nothing done yet")
                            : qsTr("Nothing waiting. Clear head.")
                        font.pixelSize: 18
                        color: win.dim
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: win.query === "" && win.filter !== "done"
                        text: qsTr("Super + N to dump a thought")
                        font.pixelSize: 13
                        color: win.faint
                    }
                }
            }

            Label {
                visible: notes.error !== ""
                text: notes.error
                color: "#ff6b6b"
                font.pixelSize: 13
            }

            // Footer
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Label {
                    text: qsTr("Space done · E edit · D delete · / search · ? all keys")
                    color: "#4a4a50"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Label {
                    text: notes.path.replace(/^\/home\/[^/]+/, "~")
                    color: "#4a4a50"
                    font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: notes.openFile() }
                }
            }
        }

        // Toast with undo
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 52
            visible: win.toast !== ""
            width: toastRow.implicitWidth + 32
            height: 40
            radius: Math.min(8, theme.radius)
            color: "#202026"
            border.color: "#2c2c33"
            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: 16
                Label { text: win.toast; color: win.text; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    visible: win.toastUndo && notes.canUndo
                    text: qsTr("Undo  Ctrl+Z")
                    color: theme.accent
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { notes.undo(); win.say(qsTr("Undone"), false) } }
                }
            }
        }

        // Shortcut overlay
        Rectangle {
            anchors.fill: parent
            visible: win.helpVisible
            color: "#f00e0e10"
            MouseArea { anchors.fill: parent; onClicked: win.helpVisible = false }
            Column {
                anchors.centerIn: parent
                spacing: 9
                Repeater {
                    model: [
                        [qsTr("Super + N"), qsTr("Quick capture from anywhere")],
                        [qsTr("J / K, arrows"), qsTr("Move")],
                        [qsTr("Space, X"), qsTr("Done / not done")],
                        [qsTr("E, Enter"), qsTr("Edit")],
                        [qsTr("D, Delete"), qsTr("Delete")],
                        [qsTr("Ctrl + Z"), qsTr("Undo")],
                        [qsTr("/, Ctrl + F"), qsTr("Search")],
                        [qsTr("1  2  3"), qsTr("Open, done, all")],
                        [qsTr("N, Ctrl + N"), qsTr("New note")],
                        [qsTr("Ctrl + O"), qsTr("Open the Markdown file")],
                        [qsTr("Esc"), qsTr("Hide")]
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: 28
                        Label { text: modelData[0]; color: theme.accent; font.pixelSize: 14; width: 150 }
                        Label { text: modelData[1]; color: win.text; font.pixelSize: 14 }
                    }
                }
            }
        }
    }
}
