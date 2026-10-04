import Quickshell
import QtQuick

// power menu, reboot and shutdown ask first
Scope {
    id: power

    property int sel: 0
    property int armed: -1

    readonly property var actions: [
        { icon: "󰌾", label: "lock", confirm: false, cmd: [Theme.bin + "kon-lock", "-f"] },
        { icon: "󰍃", label: "log out", confirm: false, cmd: [Theme.bin + "kon-wm", "quit"] },
        { icon: "󰤄", label: "suspend", confirm: false, cmd: ["systemctl", "suspend"] },
        { icon: "󰜉", label: "reboot", confirm: true, cmd: ["systemctl", "reboot"] },
        { icon: "󰐥", label: "shut down", confirm: true, cmd: ["systemctl", "poweroff"] }
    ]

    function toggle(out) {
        if (win.open) { win.hide(); return; }
        sel = 0;
        armed = -1;
        win.show(out);
        keys.forceActiveFocus();
    }

    function run(i) {
        const a = actions[i];
        if (a.confirm && armed !== i) { sel = i; armed = i; return; }
        win.hide();
        // wait for the card to close
        runner.cmd = a.cmd;
        runner.restart();
    }

    Timer {
        id: runner
        property var cmd: []
        interval: 200
        onTriggered: Quickshell.execDetached(cmd)
    }

    Overlay {
        id: win
        ns: "aroclip-power"
        framed: false
        cardWidth: 5 * 112 + 4 * 12
        cardHeight: 150
        cardTop: -1

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: (ev) => {
                const n = power.actions.length;
                if (ev.key === Qt.Key_Escape) {
                    if (power.armed >= 0) power.armed = -1;
                    else win.hide();
                } else if (ev.key === Qt.Key_Left || ev.key === Qt.Key_H || ev.key === Qt.Key_Backtab) {
                    power.sel = (power.sel + n - 1) % n; power.armed = -1;
                } else if (ev.key === Qt.Key_Right || ev.key === Qt.Key_L || ev.key === Qt.Key_Tab) {
                    power.sel = (power.sel + 1) % n; power.armed = -1;
                } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Space) {
                    power.run(power.sel);
                } else if (ev.key >= Qt.Key_1 && ev.key < Qt.Key_1 + n) {
                    power.run(ev.key - Qt.Key_1);
                } else return;
                ev.accepted = true;
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: power.actions

                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool current: index === power.sel
                    readonly property bool armed: index === power.armed
                    width: 112; height: 130

                    opacity: 0
                    transform: Translate { id: shift; y: 18 }
                    Connections {
                        target: win
                        function onOpenChanged() {
                            if (!win.open) return;
                            tile.opacity = 0; shift.y = 18;
                            enter.restart();
                        }
                    }
                    SequentialAnimation {
                        id: enter
                        PauseAnimation { duration: 40 * Theme.slow + tile.index * 35 }
                        ParallelAnimation {
                            NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 220 * Theme.slow }
                            NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.6 * Theme.bounce }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (power.sel !== tile.index) { power.sel = tile.index; power.armed = -1; }
                        onClicked: power.run(tile.index)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: tile.current ? Theme.frameFocus : Theme.frame
                        border.width: tile.current ? 2 : 1
                        border.color: tile.armed ? Theme.urgent : tile.current ? Theme.accent : Theme.border
                        scale: tile.current ? 1.0 : 0.94
                        Behavior on scale { NumberAnimation { duration: Theme.focusMs * 1.5; easing.type: Easing.OutBack; easing.overshoot: 1.70158 * Theme.bounce } }
                        Behavior on border.color { ColorAnimation { duration: Theme.focusMs } }
                        Behavior on color { ColorAnimation { duration: Theme.focusMs } }

                        Text {
                            id: glyph
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 26 }
                            text: tile.modelData.icon
                            color: tile.armed ? Theme.urgent : tile.current ? Theme.accent : Theme.dim
                            font { family: Theme.icons; pixelSize: 38 }
                            Behavior on color { ColorAnimation { duration: Theme.focusMs } }

                            SequentialAnimation on anchors.horizontalCenterOffset {
                                running: tile.armed
                                NumberAnimation { to: -5; duration: 45 * Theme.slow }
                                NumberAnimation { to: 5; duration: 70 * Theme.slow }
                                NumberAnimation { to: -3; duration: 60 * Theme.slow }
                                NumberAnimation { to: 0; duration: 50 * Theme.slow }
                            }
                        }
                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; top: glyph.bottom; topMargin: 14 }
                            text: tile.armed ? "again to confirm" : tile.modelData.label
                            color: tile.armed ? Theme.urgent : tile.current ? Theme.text : Theme.dim
                            font { family: Theme.font; pixelSize: tile.armed ? 10 : 12; bold: tile.current }
                        }
                        Text {
                            anchors { right: parent.right; top: parent.top; margins: 7 }
                            text: tile.index + 1
                            color: Theme.border
                            font { family: Theme.font; pixelSize: 10 }
                        }
                    }
                }
            }
        }
    }
}
