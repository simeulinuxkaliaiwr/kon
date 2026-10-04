import Quickshell
import Quickshell.Io
import QtQuick

// network panel, rainmeter style
Item {
    id: root
    implicitWidth: 158
    implicitHeight: 392

    property string ssid: ""
    property int signal: -1
    property string ip: ""
    property string gateway: ""
    property string dns: ""

    Process {
        id: info
        command: ["sh", "-c",
            "nmcli -t -f IN-USE,SIGNAL,SSID dev wifi list --rescan no | grep '^\\*' | head -1; echo --;"
            + " ip -4 -o addr show scope global | awk '{print $4}' | head -1; echo --;"
            + " ip route show default | awk '{print $3}' | head -1; echo --;"
            + " awk '/^nameserver/{print $2; exit}' /etc/resolv.conf"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [w, ip, gw, dns] = this.text.split("--\n").map(s => s.trim());
                if (w) { const f = w.split(":"); root.signal = parseInt(f[1]); root.ssid = f.slice(2).join(":"); }
                else { root.signal = -1; root.ssid = ""; }
                root.ip = (ip || "").split("/")[0];
                root.gateway = gw || "";
                root.dns = dns || "";
            }
        }
    }
    Timer { interval: 15000; repeat: true; running: Aero.on; triggeredOnStart: true; onTriggered: info.running = true }

    component Line: Row {
        property string label
        property string value
        property color tint: Aero.value
        spacing: 3
        Text { text: parent.label; color: Aero.inkDim; font { family: Aero.font; pixelSize: 10 } }
        Text { text: parent.value; color: parent.tint; font { family: Aero.font; pixelSize: 10 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Aero.panel
        border.color: Qt.rgba(0.45, 0.65, 0.9, 0.55)
    }

    Column {
        anchors { fill: parent; margins: 8 }
        spacing: 2

        Text {
            text: "Network Monitor"
            color: Aero.ink
            font { family: Aero.font; pixelSize: 14; bold: true }
        }
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.25) }
        Item { width: 1; height: 2 }

        Line { label: "ID:"; value: root.ssid || (Aero.iface || "offline") }
        Line { label: "Int. IP:"; value: root.ip || "none" }
        Line { label: "Gateway:"; value: root.gateway || "none" }
        Line { label: "DNS:"; value: root.dns || "none" }
        Line { label: "Interface:"; value: Aero.iface || "none" }

        Item { width: 1; height: 2 }
        Row {
            spacing: 4
            visible: root.signal >= 0
            Text { text: "Signal:"; color: Aero.inkDim; font { family: Aero.font; pixelSize: 10 } }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 74; height: 5; radius: 2
                color: Qt.rgba(1, 1, 1, 0.15)
                Rectangle { width: parent.width * Math.max(0, root.signal) / 100; height: parent.height; radius: 2; color: Aero.value }
            }
            Text { text: root.signal + "%"; color: Aero.value; font { family: Aero.font; pixelSize: 10 } }
        }

        Item { width: 1; height: 4 }
        Text { text: "\u{f0928}  Net Usage"; color: Aero.ink; font { family: Aero.font; pixelSize: 12; bold: true } }
        Line { label: "▲"; value: Aero.rate(Aero.up) + "/s"; tint: Aero.upTint }
        Line { label: "▼"; value: Aero.rate(Aero.down) + "/s"; tint: Aero.downTint }

        Item { width: 1; height: 4 }
        // last minute of traffic
        Rectangle {
            width: parent.width; height: 64
            color: Qt.rgba(0, 0, 0, 0.35)
            border.color: Qt.rgba(0.45, 0.65, 0.9, 0.45)
            Canvas {
                id: graph
                anchors { fill: parent; margins: 1 }
                property var tick: Aero.downHist
                onTickChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    c.strokeStyle = "rgba(127,196,255,0.15)";
                    c.lineWidth = 1;
                    for (let x = 0; x < width; x += 12) { c.beginPath(); c.moveTo(x + 0.5, 0); c.lineTo(x + 0.5, height); c.stroke(); }
                    for (let y = 0; y < height; y += 12) { c.beginPath(); c.moveTo(0, y + 0.5); c.lineTo(width, y + 0.5); c.stroke(); }
                    const top = Math.max(1024, ...Aero.downHist, ...Aero.upHist);
                    function plot(hist, colour) {
                        c.beginPath();
                        hist.forEach((v, i) => {
                            const x = width - (hist.length - 1 - i) * (width / 59);
                            const y = height - v / top * (height - 3);
                            if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
                        });
                        c.strokeStyle = colour;
                        c.lineWidth = 1.2;
                        c.stroke();
                    }
                    plot(Aero.downHist, "#ffd35a");
                    plot(Aero.upHist, "#8be06a");
                }
            }
            Text {
                x: 3; y: 1
                text: Aero.rate(Math.max(1024, ...Aero.downHist, ...Aero.upHist)) + "/s"
                color: Aero.inkDim
                font { family: Aero.font; pixelSize: 9 }
            }
        }

        Item { width: 1; height: 4 }
        Text { text: "Peak"; color: Aero.ink; font { family: Aero.font; pixelSize: 11; bold: true } }
        Line { label: "▲"; value: Aero.rate(Aero.upPeak) + "/s"; tint: Aero.upTint }
        Line { label: "▼"; value: Aero.rate(Aero.downPeak) + "/s"; tint: Aero.downTint }
        Text { text: "Total"; color: Aero.ink; font { family: Aero.font; pixelSize: 11; bold: true } }
        Line { label: "▲"; value: Aero.bytes(Aero.upTotal); tint: Aero.upTint }
        Line { label: "▼"; value: Aero.bytes(Aero.downTotal); tint: Aero.downTint }
        Line { label: "Σ"; value: Aero.bytes(Aero.upTotal + Aero.downTotal); tint: "#ff8a6a" }
    }
}
