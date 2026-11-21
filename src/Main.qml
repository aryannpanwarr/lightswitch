import QtQuick

// Two windows, one resident app: the capture box Super+N flips on and off,
// and the notes window the launcher opens to read what was saved.
QtObject {
    id: app

    property CaptureWindow capture: CaptureWindow {
        onOpenLibrary: app.library.summon()
    }

    property NotesWindow library: NotesWindow {
        onNewNote: app.capture.summon()
    }

    property Connections relay: Connections {
        target: ipc
        function onToggleRequested() { app.capture.visible && app.capture.active ? app.capture.release() : app.capture.summon() }
        function onShowRequested() { app.capture.summon() }
        function onOpenRequested() { app.library.summon() }
    }

    Component.onCompleted: {
        if (startMode === "open") library.summon()
        else if (startVisible) capture.summon()
    }
}
