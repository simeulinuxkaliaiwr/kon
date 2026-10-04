import QtQuick

// title bar with a search field
Item {
    id: header

    property string title
    property string info
    property alias query: search.text
    property bool active: false
    signal keyPressed(var ev)

    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 3 }
    height: 34

    onActiveChanged: if (active) { search.text = ""; search.forceActiveFocus(); }

    Text {
        id: label
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        text: header.title
        color: Theme.accent
        font { family: Theme.font; pixelSize: 13; bold: true }
    }

    TextInput {
        id: search
        anchors { left: label.right; leftMargin: 14; right: count.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        color: Theme.text
        selectionColor: Theme.accentSoft
        font { family: Theme.font; pixelSize: 13 }
        clip: true
        focus: true

        Text {
            anchors.fill: parent
            visible: search.text === ""
            text: "type to filter"
            color: Theme.dim
            font: search.font
        }

        Keys.onPressed: (ev) => header.keyPressed(ev)
    }

    Text {
        id: count
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: header.info
        color: Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }
}
