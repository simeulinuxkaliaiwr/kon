import Quickshell
import QtQuick

// system stats gadget: cpu, memory, swap, disk, traffic
Item {
    id: root
    implicitWidth: 158
    implicitHeight: 302

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // win7 progress bar
    component Meter: Item {
        property string label
        property string value
        property real fill: 0
        width: parent.width; height: 30
        Text { text: parent.label; color: Aero.ink; style: Text.Raised; styleColor: "#40000000"; font { family: Aero.font; pixelSize: 12; bold: true } }
        Text { anchors.right: parent.right; text: parent.value; color: Aero.ink; font { family: Aero.font; pixelSize: 12; bold: true } }
        Rectangle {
            y: 18; width: parent.width; height: 9; radius: 2
            border.color: Qt.rgba(0, 0, 0, 0.55)
            gradient: Gradient {
                GradientStop { position: 0; color: "#1a2028" }
                GradientStop { position: 1; color: "#3a4450" }
            }
            Rectangle {
                x: 1; y: 1; height: parent.height - 2; radius: 1
                width: Math.max(0, (parent.width - 2) * Math.min(1, Math.max(0, parent.parent.fill)))
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#9ef08f" }
                    GradientStop { position: 0.45; color: "#4ac73a" }
                    GradientStop { position: 0.5; color: "#2fae1f" }
                    GradientStop { position: 1.0; color: "#58d146" }
                }
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            }
        }
    }

    // traffic graph
    component Graph: Item {
        id: graph
        property string label
        property string value
        property var hist: []
        property color tint: Aero.value
        width: parent.width; height: 40
        Text { text: graph.label; color: Aero.ink; font { family: Aero.font; pixelSize: 12; bold: true } }
        Text { anchors.right: parent.right; text: graph.value; color: graph.tint; font { family: Aero.font; pixelSize: 12; bold: true } }
        Rectangle {
            y: 17; width: parent.width; height: 21; radius: 2
            color: Qt.rgba(0, 0, 0, 0.35)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Canvas {
                anchors { fill: parent; margins: 2 }
                property var tick: graph.hist
                onTickChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const h = tick || [];
                    if (h.length < 2) return;
                    const t = graph.tint;
                    const top = Math.max(1024, ...h);
                    const px = i => width - (h.length - 1 - i) * (width / 59);
                    const py = v => height - v / top * (height - 1);
                    c.beginPath();
                    c.moveTo(px(0), height);
                    h.forEach((v, i) => c.lineTo(px(i), py(v)));
                    c.lineTo(px(h.length - 1), height);
                    c.closePath();
                    const g = c.createLinearGradient(0, 0, 0, height);
                    g.addColorStop(0, Qt.rgba(t.r, t.g, t.b, 0.45));
                    g.addColorStop(1, Qt.rgba(t.r, t.g, t.b, 0.02));
                    c.fillStyle = g;
                    c.fill();
                    c.beginPath();
                    h.forEach((v, i) => i === 0 ? c.moveTo(px(i), py(v)) : c.lineTo(px(i), py(v)));
                    c.strokeStyle = t;
                    c.lineWidth = 1.2;
                    c.stroke();
                }
            }
        }
    }

    // shadow and body
    Rectangle {
        x: 2; y: 4; width: parent.width - 2; height: parent.height - 4; radius: 12
        color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        width: parent.width - 3; height: parent.height - 5; radius: 12
        border.color: Qt.rgba(0, 0, 0, 0.55)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.29, 0.35, 0.41, 0.82) }
            GradientStop { position: 0.5; color: Qt.rgba(0.11, 0.14, 0.18, 0.82) }
            GradientStop { position: 1.0; color: Qt.rgba(0.17, 0.21, 0.25, 0.82) }
        }
        // inner edge
        Rectangle {
            anchors { fill: parent; margins: 1 }
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.28)
        }
        // gloss
        Rectangle {
            x: 1; y: 1; width: parent.width - 2; height: parent.height * 0.42; radius: 11
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.02) }
            }
        }

        Column {
            anchors { fill: parent; margins: 11; topMargin: 9 }
            spacing: 3
            Meter { label: "CPU"; value: Math.round(Aero.cpu * 100) + " %"; fill: Aero.cpu }
            Meter { label: "RAM"; value: Aero.gig(Aero.memUsed) + " / " + Aero.gig(Aero.memTotal); fill: Aero.memUsed / Aero.memTotal }
            Meter { label: "Swap"; value: Aero.gig(Aero.swapUsed); fill: Aero.swapTotal > 0 ? Aero.swapUsed / Aero.swapTotal : 0 }
            Meter { label: "Disk /"; value: Aero.gig(Aero.diskUsed); fill: Aero.diskUsed / Aero.diskTotal }
            Graph { label: "Up"; value: Aero.rate(Aero.up) + "/s"; hist: Aero.upHist; tint: Aero.upTint }
            Graph { label: "Down"; value: Aero.rate(Aero.down) + "/s"; hist: Aero.downHist; tint: Aero.downTint }
            Item { width: 1; height: 2 }
            Text {
                anchors.right: parent.right
                text: Qt.formatTime(clock.date, "HH:mm:ss")
                color: Aero.ink
                style: Text.Raised; styleColor: "#60000000"
                font { family: Aero.font; pixelSize: 20; weight: Font.Light }
            }
            Text {
                anchors.right: parent.right
                text: Qt.formatDate(clock.date, "dddd, d MMM")
                color: Aero.inkDim
                font { family: Aero.font; pixelSize: 11 }
            }
        }
    }
}
