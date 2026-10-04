import Quickshell
import QtQuick

// win7 clock gadget
Item {
    id: root
    implicitWidth: 160
    implicitHeight: 160

    SystemClock { id: clock; precision: SystemClock.Seconds }

    Canvas {
        id: face
        anchors.fill: parent
        antialiasing: true
        property var now: clock.date
        onNowChanged: requestPaint()

        onPaint: {
            const c = getContext("2d");
            const w = width, r = w / 2 - 4, cx = w / 2, cy = height / 2;
            c.reset();

            // drop shadow
            c.beginPath();
            c.arc(cx + 2, cy + 3, r, 0, Math.PI * 2);
            c.fillStyle = "rgba(0,0,0,0.35)";
            c.fill();

            // metal rim
            let g = c.createLinearGradient(0, cy - r, 0, cy + r);
            g.addColorStop(0, "#5a6878");
            g.addColorStop(0.5, "#1a222c");
            g.addColorStop(1, "#46525f");
            c.beginPath();
            c.arc(cx, cy, r, 0, Math.PI * 2);
            c.fillStyle = g;
            c.fill();

            // face
            const fr = r * 0.84;
            g = c.createRadialGradient(cx - fr * 0.3, cy - fr * 0.35, fr * 0.1, cx, cy, fr);
            g.addColorStop(0, "#f4fbff");
            g.addColorStop(0.55, "#bfe0f7");
            g.addColorStop(1, "#5da4d8");
            c.beginPath();
            c.arc(cx, cy, fr, 0, Math.PI * 2);
            c.fillStyle = g;
            c.fill();

            // ticks and numbers
            for (let i = 0; i < 60; i++) {
                const a = i / 60 * Math.PI * 2 - Math.PI / 2;
                const big = i % 5 === 0;
                const r1 = fr * (big ? 0.86 : 0.91), r2 = fr * 0.96;
                c.beginPath();
                c.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
                c.lineTo(cx + Math.cos(a) * r2, cy + Math.sin(a) * r2);
                c.strokeStyle = big ? "#1d2a38" : "#4c6a86";
                c.lineWidth = big ? 2 : 1;
                c.stroke();
            }
            c.fillStyle = "#16202b";
            c.font = "bold " + Math.round(fr * 0.2) + "px 'Open Sans'";
            c.textAlign = "center";
            c.textBaseline = "middle";
            for (let n = 1; n <= 12; n++) {
                const a = n / 12 * Math.PI * 2 - Math.PI / 2;
                c.fillText(String(n), cx + Math.cos(a) * fr * 0.7, cy + Math.sin(a) * fr * 0.7);
            }

            // hands
            const d = now;
            const s = d.getSeconds(), m = d.getMinutes() + s / 60, h = d.getHours() % 12 + m / 60;
            function hand(frac, len, width, colour) {
                const a = frac * Math.PI * 2 - Math.PI / 2;
                c.beginPath();
                c.moveTo(cx - Math.cos(a) * len * 0.15, cy - Math.sin(a) * len * 0.15);
                c.lineTo(cx + Math.cos(a) * len, cy + Math.sin(a) * len);
                c.strokeStyle = colour;
                c.lineWidth = width;
                c.lineCap = "round";
                c.stroke();
            }
            hand(h / 12, fr * 0.5, 4.5, "#1f6fc0");
            hand(m / 60, fr * 0.75, 3.5, "#2a86e0");
            hand(s / 60, fr * 0.82, 1.2, "#d0342c");
            c.beginPath();
            c.arc(cx, cy, 3.5, 0, Math.PI * 2);
            c.fillStyle = "#16202b";
            c.fill();

            // reflection
            g = c.createLinearGradient(0, cy - fr, 0, cy);
            g.addColorStop(0, "rgba(255,255,255,0.55)");
            g.addColorStop(1, "rgba(255,255,255,0.02)");
            c.beginPath();
            c.ellipse(cx - fr * 0.78, cy - fr * 0.95, fr * 1.56, fr * 0.95);
            c.fillStyle = g;
            c.fill();
        }
    }
}
