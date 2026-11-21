import QtQuick
import QtQuick.Controls

// One note in the grid. Done and delete show on hover, like Keep.
Rectangle {
    id: card
    required property var modelData
    signal open(int line)
    signal done(int line)
    signal discard(int line)

    readonly property bool hovered: hover.hovered

    height: body.implicitHeight + 64
    radius: 8
    color: "#18181c"
    border.color: hovered ? "#4a4a52" : "#2a2a30"

    HoverHandler { id: hover }
    TapHandler { onTapped: card.open(card.modelData.line) }

    Label {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        text: card.modelData.text
        wrapMode: Text.Wrap
        maximumLineCount: 12
        elide: Text.ElideRight
        font.pixelSize: 15
        lineHeight: 1.15
        color: "#e8e8ea"
    }

    Label {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        text: card.modelData.day + " · " + card.modelData.time
        font.pixelSize: 11
        color: "#6a6a70"
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        spacing: 2
        opacity: card.hovered ? 1 : 0

        Repeater {
            model: [
                { glyph: "✓", tip: qsTr("Done"), action: "done" },
                { glyph: "🗑", tip: qsTr("Delete"), action: "discard" }
            ]
            delegate: Rectangle {
                required property var modelData
                width: 32; height: 32; radius: 16
                color: iconHover.hovered ? "#2c2c33" : "transparent"
                Label {
                    anchors.centerIn: parent
                    text: modelData.glyph
                    font.pixelSize: 15
                    color: "#b0b0b6"
                }
                HoverHandler { id: iconHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: modelData.action === "done" ? card.done(card.modelData.line) : card.discard(card.modelData.line) }
                ToolTip.visible: iconHover.hovered
                ToolTip.text: modelData.tip
                ToolTip.delay: 400
            }
        }
    }
}
