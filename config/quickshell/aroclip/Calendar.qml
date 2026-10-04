import Quickshell
import QtQuick

// month popup under the clock
PopupWindow {
    id: cal
    property Item anchorItem
    property bool above: false   // open upwards
    property bool open: false
    property date month: new Date()

    function toggle() {
        if (open) { open = false; return; }
        month = new Date();
        open = true;
    }
    function shift(n) { month = new Date(month.getFullYear(), month.getMonth() + n, 1); }

    visible: open || card.opacity > 0
    color: "transparent"
    anchor.item: anchorItem
    // centred under the clock
    anchor.rect.x: 0
    anchor.rect.y: above ? -6 : 0
    anchor.rect.width: anchorItem ? anchorItem.width : 0
    anchor.rect.height: anchorItem ? anchorItem.height + 6 : 0
    anchor.edges: above ? Edges.Top : Edges.Bottom
    anchor.gravity: above ? Edges.Top : Edges.Bottom
    implicitWidth: 260
    implicitHeight: 262

    // weeks start on monday
    readonly property var days: {
        const y = month.getFullYear(), m = month.getMonth();
        const first = new Date(y, m, 1);
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(y, m, 1 - lead + i));
        return out;
    }

    Item {
        id: card
        anchors.fill: parent
        opacity: cal.open ? 1 : 0
        transform: Translate { y: cal.open ? 0 : -10; Behavior on y { NumberAnimation { duration: 260 * Theme.slow; easing.type: Easing.OutBack; easing.overshoot: 1.70158 * Theme.bounce } } }
        Behavior on opacity { NumberAnimation { duration: 180 * Theme.slow } }

        Rectangle {
            anchors.fill: parent
            radius: Aero.on ? 3 : Theme.radius
            color: Theme.frameFocus
            gradient: Aero.on ? Aero.flyout : null
            border.width: Aero.on ? 1 : Theme.borderWidth
            border.color: Aero.on ? Aero.flyoutEdge : Theme.accent
        }

        MouseArea {
            anchors.fill: parent
            onWheel: (w) => cal.shift(w.angleDelta.y > 0 ? -1 : 1)
        }

        Item {
            id: head
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
            height: 24
            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(cal.month, "MMMM yyyy").toLowerCase()
                color: Theme.accent
                font { family: Theme.font; pixelSize: 13; bold: true }
            }
            Repeater {
                model: [{ t: "󰅁", n: -1, left: true }, { t: "󰅂", n: 1, left: false }]
                Text {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    x: modelData.left ? 2 : head.width - width - 2
                    text: modelData.t
                    color: arrow.containsMouse ? Theme.accent : Theme.dim
                    font { family: Theme.icons; pixelSize: 14 }
                    MouseArea { id: arrow; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: cal.shift(parent.modelData.n) }
                }
            }
        }

        Grid {
            id: grid
            anchors { top: head.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
            columns: 7
            spacing: 2
            Repeater {
                model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
                Text {
                    required property string modelData
                    width: 32; height: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 10; bold: true }
                }
            }
            Repeater {
                model: cal.days
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool inMonth: modelData.getMonth() === cal.month.getMonth()
                    readonly property bool today: modelData.toDateString() === new Date().toDateString()
                    width: 32; height: 28
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26; radius: 13
                        color: Theme.accent
                        visible: parent.today
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.getDate()
                        color: parent.today ? Theme.accentInk : parent.inMonth ? Theme.text : Theme.border
                        font { family: Theme.font; pixelSize: 12; bold: parent.today }
                    }
                }
            }
        }
    }
}
