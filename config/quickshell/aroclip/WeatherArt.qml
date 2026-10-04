import QtQuick

// weather icons drawn in qml
Canvas {
    id: art
    property int code: 0
    property bool day: true
    width: 120
    height: 100
    antialiasing: true
    onCodeChanged: requestPaint()
    onDayChanged: requestPaint()
    onWidthChanged: requestPaint()

    // parts for each WMO code
    readonly property bool clear: code <= 1
    readonly property bool partly: code === 2
    readonly property bool cloudy: code >= 2
    readonly property bool grey: code === 3 || code === 45 || code === 48 || code >= 51
    readonly property bool rain: (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95
    readonly property bool snow: (code >= 71 && code <= 77) || code === 85 || code === 86
    readonly property bool storm: code >= 95
    readonly property bool fog: code === 45 || code === 48

    onPaint: {
        const c = getContext("2d");
        c.reset();
        const u = width / 120;          // drawn at 120 x 100, scaled
        c.scale(u, u);

        function orb(x, y, r) {
            if (art.day) {
                let g = c.createRadialGradient(x, y, r * 0.6, x, y, r * 1.9);
                g.addColorStop(0, "rgba(255,220,90,0.55)");
                g.addColorStop(1, "rgba(255,200,60,0)");
                c.fillStyle = g;
                c.beginPath(); c.arc(x, y, r * 1.9, 0, Math.PI * 2); c.fill();
                g = c.createRadialGradient(x - r * 0.35, y - r * 0.4, r * 0.1, x, y, r);
                g.addColorStop(0, "#fff7b0");
                g.addColorStop(0.5, "#ffd23a");
                g.addColorStop(1, "#f08a12");
                c.fillStyle = g;
                c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill();
            } else {
                // crescent moon
                let g = c.createRadialGradient(x - r * 0.3, y - r * 0.3, r * 0.1, x, y, r);
                g.addColorStop(0, "#ffffff");
                g.addColorStop(1, "#c9d6ea");
                c.fillStyle = g;
                c.beginPath(); c.arc(x, y, r * 0.85, 0, Math.PI * 2); c.fill();
                c.globalCompositeOperation = "destination-out";
                c.beginPath(); c.arc(x + r * 0.45, y - r * 0.25, r * 0.72, 0, Math.PI * 2); c.fill();
                c.globalCompositeOperation = "source-over";
            }
            const s = c.createLinearGradient(0, y - r, 0, y);
            s.addColorStop(0, "rgba(255,255,255,0.7)");
            s.addColorStop(1, "rgba(255,255,255,0)");
            c.fillStyle = s;
            c.beginPath(); c.ellipse(x - r * 0.6, y - r * 0.92, r * 1.2, r * 0.8); c.fill();
        }

        function cloud(x, y, w, dark) {
            const h = w * 0.55;
            // shadow
            const sh = c.createRadialGradient(x, y + h * 0.5, 2, x, y + h * 0.5, w * 0.55);
            sh.addColorStop(0, "rgba(0,0,0,0.28)");
            sh.addColorStop(1, "rgba(0,0,0,0)");
            c.fillStyle = sh;
            c.beginPath(); c.ellipse(x - w * 0.55, y + h * 0.25, w * 1.1, h * 0.5); c.fill();
            // fill puffs separately so overlaps don't cut holes
            const g = c.createLinearGradient(0, y - h * 0.7, 0, y + h * 0.46);
            g.addColorStop(0, dark ? "#d5dbe3" : "#ffffff");
            g.addColorStop(1, dark ? "#7b8796" : "#c4d4e6");
            c.fillStyle = g;
            for (const [px, py, pr] of [[x - w * 0.28, y + h * 0.08, h * 0.38],
                                        [x + w * 0.26, y + h * 0.02, h * 0.42],
                                        [x - w * 0.02, y - h * 0.18, h * 0.52]]) {
                c.beginPath(); c.arc(px, py, pr, 0, Math.PI * 2); c.fill();
            }
            c.beginPath(); c.rect(x - w * 0.28, y + h * 0.05, w * 0.54, h * 0.41); c.fill();
            // shine
            const s = c.createLinearGradient(0, y - h * 0.7, 0, y);
            s.addColorStop(0, "rgba(255,255,255,0.75)");
            s.addColorStop(1, "rgba(255,255,255,0)");
            c.fillStyle = s;
            c.beginPath(); c.ellipse(x - w * 0.22, y - h * 0.66, w * 0.4, h * 0.4); c.fill();
        }

        function drops(x, y) {
            for (let i = 0; i < 3; i++) {
                const dx = x + (i - 1) * 16, dy = y + (i % 2) * 7;
                const g = c.createLinearGradient(dx - 4, dy, dx + 4, dy + 12);
                g.addColorStop(0, "#bfe6ff");
                g.addColorStop(1, "#2a78d0");
                c.fillStyle = g;
                c.beginPath();
                c.moveTo(dx, dy);
                c.bezierCurveTo(dx + 5, dy + 6, dx + 5, dy + 12, dx, dy + 12);
                c.bezierCurveTo(dx - 5, dy + 12, dx - 5, dy + 6, dx, dy);
                c.fill();
            }
        }

        function flakes(x, y) {
            c.strokeStyle = "#ffffff";
            c.lineWidth = 1.6;
            c.lineCap = "round";
            for (let i = 0; i < 3; i++) {
                const fx = x + (i - 1) * 17, fy = y + (i % 2) * 8 + 4, r = 5;
                for (let a = 0; a < 3; a++) {
                    const t = a * Math.PI / 3;
                    c.beginPath();
                    c.moveTo(fx - Math.cos(t) * r, fy - Math.sin(t) * r);
                    c.lineTo(fx + Math.cos(t) * r, fy + Math.sin(t) * r);
                    c.stroke();
                }
            }
        }

        function bolt(x, y) {
            const g = c.createLinearGradient(x, y, x + 10, y + 26);
            g.addColorStop(0, "#fff6a0");
            g.addColorStop(1, "#f2b10c");
            c.fillStyle = g;
            c.beginPath();
            c.moveTo(x + 6, y); c.lineTo(x - 4, y + 15); c.lineTo(x + 3, y + 15);
            c.lineTo(x - 2, y + 28); c.lineTo(x + 12, y + 10); c.lineTo(x + 5, y + 10); c.lineTo(x + 10, y);
            c.closePath();
            c.fill();
        }

        if (art.clear) {
            orb(60, 46, 26);
        } else {
            if (art.partly) orb(76, 34, 20);
            cloud(art.partly ? 52 : 60, 54, art.partly ? 70 : 84, art.grey);
            if (art.code === 3 || art.fog) cloud(84, 42, 50, true);
        }
        if (art.storm) bolt(56, 66);
        else if (art.rain) drops(60, 74);
        if (art.snow) flakes(60, 74);
        if (art.fog) {
            c.strokeStyle = "rgba(255,255,255,0.7)";
            c.lineWidth = 3;
            c.lineCap = "round";
            for (let i = 0; i < 3; i++) {
                c.beginPath(); c.moveTo(26 + i * 6, 76 + i * 7); c.lineTo(96 - i * 4, 76 + i * 7); c.stroke();
            }
        }
    }
}
