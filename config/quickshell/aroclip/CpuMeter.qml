import QtQuick

// win7 cpu meter gadget
Item {
    id: root
    implicitWidth: 200
    implicitHeight: 160

    // smooth the needles
    property real cpu: Aero.cpu
    property real mem: Aero.memUsed / Aero.memTotal
    Behavior on cpu { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    Behavior on mem { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    onCpuChanged: face.requestPaint()
    onMemChanged: face.requestPaint()

    Canvas {
        id: face
        anchors.fill: parent
        antialiasing: true

        // 0..1 maps to 270 degrees
        function angle(v) { return (135 + Math.max(0, Math.min(1, v)) * 270) * Math.PI / 180; }

        function dial(c, cx, cy, r, v) {
            // rim
            let g = c.createLinearGradient(0, cy - r, 0, cy + r);
            g.addColorStop(0, "#d9dfe6");
            g.addColorStop(0.5, "#5b6672");
            g.addColorStop(1, "#aab4bf");
            c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.fillStyle = g; c.fill();

            // face
            const fr = r * 0.88;
            g = c.createRadialGradient(cx, cy - fr * 0.3, fr * 0.1, cx, cy, fr);
            g.addColorStop(0, "#3a4654");
            g.addColorStop(1, "#0b0f14");
            c.beginPath(); c.arc(cx, cy, fr, 0, Math.PI * 2); c.fillStyle = g; c.fill();

            // red zone
            c.beginPath();
            c.arc(cx, cy, fr * 0.8, angle(0.8), angle(1));
            c.strokeStyle = "rgba(225,50,40,0.85)";
            c.lineWidth = fr * 0.1;
            c.stroke();

            // ticks
            for (let i = 0; i <= 20; i++) {
                const a = angle(i / 20), big = i % 2 === 0;
                const r1 = fr * (big ? 0.68 : 0.74), r2 = fr * 0.86;
                c.beginPath();
                c.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
                c.lineTo(cx + Math.cos(a) * r2, cy + Math.sin(a) * r2);
                c.strokeStyle = big ? "#f2f6fa" : "#8d9aa8";
                c.lineWidth = big ? 1.6 : 1;
                c.stroke();
            }

            // needle
            const a = angle(v), len = fr * 0.8;
            c.save();
            c.translate(cx, cy);
            c.rotate(a);
            c.beginPath();
            c.moveTo(-fr * 0.14, -1.6); c.lineTo(len * 0.7, -1.1); c.lineTo(len * 0.7, 1.1); c.lineTo(-fr * 0.14, 1.6);
            c.closePath();
            c.fillStyle = "#f4f7fa"; c.fill();
            c.beginPath();
            c.moveTo(len * 0.7, -1.1); c.lineTo(len, 0); c.lineTo(len * 0.7, 1.1);
            c.closePath();
            c.fillStyle = "#e8392c"; c.fill();
            c.restore();

            // cap
            g = c.createRadialGradient(cx - 1.5, cy - 1.5, 0.5, cx, cy, fr * 0.13);
            g.addColorStop(0, "#ffffff");
            g.addColorStop(1, "#58636f");
            c.beginPath(); c.arc(cx, cy, fr * 0.12, 0, Math.PI * 2); c.fillStyle = g; c.fill();

            // glass
            g = c.createLinearGradient(0, cy - fr, 0, cy);
            g.addColorStop(0, "rgba(255,255,255,0.32)");
            g.addColorStop(1, "rgba(255,255,255,0.02)");
            c.beginPath(); c.ellipse(cx - fr * 0.8, cy - fr * 0.96, fr * 1.6, fr * 0.98); c.fillStyle = g; c.fill();
        }

        // lcd readout
        function readout(c, x, y, w, text) {
            c.beginPath();
            c.rect(x, y, w, 15);
            c.fillStyle = "#05080b"; c.fill();
            c.strokeStyle = "rgba(255,255,255,0.25)"; c.lineWidth = 1; c.stroke();
            c.fillStyle = "#7cf06a";
            c.font = "bold 11px 'Open Sans'";
            c.textAlign = "center";
            c.textBaseline = "middle";
            c.fillText(text, x + w / 2, y + 8);
        }

        onPaint: {
            const c = getContext("2d");
            c.reset();
            const w = width, h = height;

            // shadow and body
            c.beginPath(); c.roundedRect(3, 5, w - 4, h - 6, 14, 14); c.fillStyle = "rgba(0,0,0,0.35)"; c.fill();
            let g = c.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0, "#4b5868");
            g.addColorStop(0.5, "#1c242e");
            g.addColorStop(1, "#2b3540");
            c.beginPath(); c.roundedRect(1, 1, w - 4, h - 6, 14, 14); c.fillStyle = g; c.fill();
            c.strokeStyle = "rgba(255,255,255,0.35)"; c.lineWidth = 1; c.stroke();

            dial(c, 74, 74, 62, root.cpu);
            dial(c, 158, 50, 36, root.mem);

            readout(c, 46, 138, 56, Math.round(Aero.cpu * 100) + " %");
            readout(c, 132, 92, 52, Math.round(Aero.memUsed / Aero.memTotal * 100) + " %");

            // shine
            g = c.createLinearGradient(0, 0, 0, h * 0.45);
            g.addColorStop(0, "rgba(255,255,255,0.18)");
            g.addColorStop(1, "rgba(255,255,255,0)");
            c.beginPath(); c.roundedRect(1, 1, w - 4, h * 0.45, 14, 14); c.fillStyle = g; c.fill();
        }
    }
}
