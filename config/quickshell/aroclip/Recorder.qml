import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// screen recording with wl-screenrec
Scope {
    id: rec

    readonly property bool active: proc.running
    property string output: ""
    property string file: ""
    property int seconds: 0
    signal finished(string file, string output, bool ok)

    readonly property string dir: Theme.home + "/Videos/Recordings"

    function toggle(out, geometry) {
        if (proc.running) { stop(); return; }
        output = out;
        file = dir + "/rec-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        const where = geometry !== "" ? ["-g", geometry] : ["-o", out];
        proc.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec wl-screenrec --no-hw "$@"', "sh", dir].concat(where, ["-f", file]);
        seconds = 0;
        proc.running = true;
    }

    function stop() { if (proc.running) proc.signal(2); }

    Process {
        id: proc
        onExited: (code) => {
            const ok = rec.seconds > 0 || code === 0;
            if (ok) Quickshell.execDetached(["sh", "-c", 'printf "file://%s\\n" "$1" | wl-copy --type text/uri-list', "sh", rec.file]);
            rec.finished(rec.file, rec.output, ok);
        }
    }

    Timer { interval: 1000; repeat: true; running: proc.running; onTriggered: rec.seconds++ }

    PanelWindow {
        id: win
        visible: proc.running || pill.opacity > 0
        screen: Theme.screenFor(rec.output)
        color: "transparent"
        anchors { bottom: true; left: true }
        implicitWidth: 150
        implicitHeight: 70
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "aroclip-rec"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            id: pill
            width: 118; height: 34
            x: 18
            y: proc.running ? parent.height - height - 18 : parent.height
            opacity: proc.running ? 1 : 0
            Behavior on y { NumberAnimation { duration: Theme.animMs; easing.type: proc.running ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.70158 * Theme.bounce } }
            Behavior on opacity { NumberAnimation { duration: 220 * Theme.slow } }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rec.stop()
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.frameFocus
                border.width: Theme.borderWidth
                border.color: hover.containsMouse ? Theme.accent : Theme.urgent
                Behavior on border.color { ColorAnimation { duration: Theme.focusMs } }
            }

            // recording dot
            Rectangle {
                id: dot
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 10; height: 10; radius: 5
                color: Theme.urgent
                SequentialAnimation on opacity {
                    running: proc.running; loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 700 * Theme.slow; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700 * Theme.slow; easing.type: Easing.InOutSine }
                }
            }
            Rectangle {
                anchors.centerIn: dot
                width: 10; height: 10; radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: Theme.urgent
                NumberAnimation on scale {
                    running: proc.running; loops: Animation.Infinite
                    from: 1; to: 2.6; duration: 1400 * Theme.slow; easing.type: Easing.OutCubic
                }
                NumberAnimation on opacity {
                    running: proc.running; loops: Animation.Infinite
                    from: 0.8; to: 0; duration: 1400 * Theme.slow; easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors { left: dot.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: hover.containsMouse ? "stop"
                    : String(Math.floor(rec.seconds / 60)).padStart(2, "0") + ":" + String(rec.seconds % 60).padStart(2, "0")
                color: Theme.text
                font { family: Theme.font; pixelSize: 12; bold: true }
            }
        }
    }
}
