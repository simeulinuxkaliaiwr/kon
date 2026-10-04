import Quickshell
import Quickshell.Wayland
import QtQuick

// volume/mic/brightness popup
Scope {
    id: osd

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string output: ""
    property bool open: false

    readonly property string glyph: {
        if (kind === "brightness") return value < 0.34 ? "󰃞" : value < 0.67 ? "󰃟" : "󰃠";
        if (kind === "mic") return muted ? "󰍭" : "󰍬";
        if (muted || value === 0) return "󰝟";
        return value < 0.34 ? "󰕿" : value < 0.67 ? "󰖀" : "󰕾";
    }

    function show(k, v, m, out) {
        kind = k;
        value = Math.max(0, Math.min(1, v));
        muted = m;
        output = out;
        open = true;
        linger.restart();
    }

    Timer { id: linger; interval: 1400; onTriggered: osd.open = false }

    PanelWindow {
        id: win
        visible: osd.open || pill.opacity > 0
        screen: Theme.screenFor(osd.output)
        color: "transparent"
        anchors { bottom: true }
        implicitWidth: 300
        implicitHeight: 90
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "aroclip-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Item {
            id: pill
            width: 260; height: 44
            anchors.horizontalCenter: parent.horizontalCenter
            y: osd.open ? parent.height - height - 28 : parent.height
            opacity: osd.open ? 1 : 0
            scale: osd.open ? 1 : 0.9
            Behavior on y { NumberAnimation { duration: Theme.animMs; easing.type: osd.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.70158 * Theme.bounce } }
            Behavior on opacity { NumberAnimation { duration: 200 * Theme.slow } }
            Behavior on scale { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.70158 * Theme.bounce } }

            Rectangle {
                anchors.fill: parent
                radius: Aero.on ? 3 : height / 2
                color: Theme.frameFocus
                gradient: Aero.on ? Aero.flyout : null
                border.width: Aero.on ? 1 : Theme.borderWidth
                border.color: Aero.on ? Aero.flyoutEdge : osd.muted ? Theme.border : Theme.accent
                Behavior on border.color { ColorAnimation { duration: Theme.focusMs } }
            }

            Text {
                id: icon
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: 20
                text: osd.glyph
                color: osd.muted ? Theme.dim : Theme.accent
                font { family: Theme.icons; pixelSize: 17 }
            }

            Rectangle {
                id: track
                anchors { left: icon.right; leftMargin: 10; right: pct.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                height: 6
                radius: 3
                color: Theme.border

                Rectangle {
                    height: parent.height
                    radius: 3
                    width: parent.width * (osd.kind === "mic" ? (osd.muted ? 0 : 1) : osd.value)
                    color: osd.muted ? Theme.dim : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.focusMs; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.focusMs } }
                }
            }

            Text {
                id: pct
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                width: 38
                horizontalAlignment: Text.AlignRight
                text: osd.kind === "mic" ? (osd.muted ? "off" : "on")
                    : osd.muted ? "mute" : Math.round(osd.value * 100) + "%"
                color: osd.muted ? Theme.dim : Theme.text
                font { family: Theme.font; pixelSize: 12; bold: true }
            }
        }
    }
}
