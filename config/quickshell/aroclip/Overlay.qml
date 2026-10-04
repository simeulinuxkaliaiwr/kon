import Quickshell
import Quickshell.Wayland
import QtQuick

// dimmed screen with a popup card
PanelWindow {
    id: win

    property bool open: false
    property bool shown: false   // true until the close animation ends
    property string output: ""
    property string ns: "aroclip"
    property real cardWidth: 620
    property real cardHeight: 480
    property real cardTop: 0.16      // of the screen height; < 0 centres it
    property bool framed: true
    default property alias content: card.data
    readonly property alias card: card

    // use the screen size, the window is 0x0 at first
    readonly property real sw: screen ? screen.width : width
    readonly property real sh: screen ? screen.height : height

    function show(out) { output = out; shown = true; open = true; }
    function hide() { open = false; }

    visible: shown
    screen: Theme.screenFor(output)
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: ns
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: win.open ? (Aero.on ? 0.12 : 0.35) : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animMs * 0.6; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: win.hide() }
    }

    Item {
        id: card
        readonly property real restY: win.cardTop < 0 ? (win.sh - height) / 2 : win.sh * win.cardTop
        width: Math.min(win.sw - 48, win.cardWidth)
        height: Math.min(win.sh - 96, win.cardHeight)
        x: (win.sw - width) / 2
        transformOrigin: Item.Top
        opacity: 0
        scale: 0.88
        y: restY

        state: win.open ? "in" : "out"
        states: [
            State { name: "in"; PropertyChanges { card.opacity: 1; card.scale: 1; card.y: card.restY } },
            State { name: "out"; PropertyChanges { card.opacity: 0; card.scale: 0.94; card.y: card.restY - 12 } }
        ]
        transitions: [
            Transition {
                to: "in"
                NumberAnimation { properties: "scale,y"; duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.2 * Theme.bounce }
                NumberAnimation { property: "opacity"; duration: Theme.animMs * 0.6; easing.type: Easing.OutCubic }
            },
            Transition {
                to: "out"
                SequentialAnimation {
                    NumberAnimation { properties: "scale,y,opacity"; duration: 180 * Theme.slow; easing.type: Easing.InCubic }
                    ScriptAction { script: win.shown = false }
                }
            }
        ]

        MouseArea { anchors.fill: parent }

        // win7 style window
        Item {
            visible: win.framed && Aero.on
            anchors { fill: parent; margins: -7 }
            Rectangle {
                anchors.fill: parent
                radius: 7
                border.color: Qt.rgba(0, 0, 0, 0.55)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.80, 0.88, 0.96, 0.94) }
                    GradientStop { position: 1; color: Qt.rgba(0.56, 0.70, 0.85, 0.90) }
                }
            }
            Rectangle {
                anchors { fill: parent; margins: 1 }
                radius: 6
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.6)
            }
            Rectangle {
                anchors { fill: parent; margins: 7 }
                radius: 2
                color: "#fbfcfd"
                border.color: Qt.rgba(0.35, 0.45, 0.55, 0.7)
            }
        }

        // card frame
        Rectangle {
            visible: win.framed && !Aero.on
            anchors.fill: parent
            radius: Theme.radius
            color: Qt.rgba(Theme.frameFocus.r, Theme.frameFocus.g, Theme.frameFocus.b, Math.min(1, Theme.glass + 0.06))
            border.width: Theme.borderWidth
            border.color: Theme.accent
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Theme.radius - 1
                color: "transparent"
                border.width: 1
                border.color: Theme.accentSoft
            }
        }
    }
}
