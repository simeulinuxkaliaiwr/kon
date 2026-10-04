pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// aero colours and system stats
Singleton {
    id: aero

    readonly property bool on: Theme.layout === "aero"
    property bool widgetsHidden: false  // the taskbar's show-desktop sliver

    readonly property string font: "Open Sans"
    readonly property color ink: "#ffffff"
    readonly property color inkDim: "#b9c9da"
    readonly property color value: "#7fc4ff"
    readonly property color upTint: "#8be06a"
    readonly property color downTint: "#ffd35a"
    readonly property color panel: Qt.rgba(0.07, 0.10, 0.15, 0.62)
    readonly property color panelEdge: Qt.rgba(1, 1, 1, 0.22)
    readonly property color flyoutEdge: "#767676"
    // win7 tooltip gradient
    readonly property Gradient flyout: Gradient {
        GradientStop { position: 0; color: "#ffffff" }
        GradientStop { position: 1; color: "#e4e5f0" }
    }

    // set these to pin the weather to a place, else it follows your ip
    readonly property string pinCity: ""
    readonly property real pinLat: NaN
    readonly property real pinLon: NaN

    readonly property bool pinned: !isNaN(pinLat) && !isNaN(pinLon)
    property string city: pinned ? pinCity : ""
    property real lat: pinned ? pinLat : NaN
    property real lon: pinned ? pinLon : NaN
    readonly property bool located: !isNaN(lat) && !isNaN(lon)

    function place(j) {
        const ll = (j.loc ?? "").split(",").map(Number);
        if (ll.length !== 2 || ll.some(isNaN)) return false;
        aero.lat = ll[0];
        aero.lon = ll[1];
        aero.city = [j.city, j.country].filter(x => x).join(", ");
        return true;
    }

    // last known place, so the weather shows up offline and right after login
    FileView {
        id: lastPlace
        path: Theme.cacheDir + "/location.json"
        printErrors: false
        onLoaded: if (!aero.pinned && !aero.located) { try { aero.place(JSON.parse(text())); } catch (e) {} }
    }
    Process {
        id: locate
        command: ["curl", "-sf", "--max-time", "10", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j;
                try { j = JSON.parse(this.text); } catch (e) { return; }
                if (aero.place(j))
                    lastPlace.setText(JSON.stringify({ city: j.city, country: j.country, loc: j.loc }));
            }
        }
    }
    Timer { interval: 21600000; repeat: true; running: aero.on && !aero.pinned; triggeredOnStart: true; onTriggered: locate.running = true }

    property real cpu: 0                // 0..1
    property real memUsed: 0            // bytes
    property real memTotal: 1
    property real swapUsed: 0
    property real swapTotal: 0
    property real up: 0                 // bytes per second
    property real down: 0
    property real upPeak: 0
    property real downPeak: 0
    property real upTotal: 0            // since the shell started
    property real downTotal: 0
    property var upHist: []             // the last minute
    property var downHist: []
    property var cpuHist: []
    property string iface: ""
    property real diskUsed: 0
    property real diskTotal: 1

    property var prevCpu: null
    property var prevNet: null
    property real prevT: 0

    function push(arr, v) { const a = arr.slice(-59); a.push(v); return a; }

    // 5.6 G, 138.2 G
    function gig(b) { return (b / 1073741824).toFixed(1) + " G"; }
    // 14 k, 1.2 M per second
    function rate(b) {
        if (b < 1024) return Math.round(b) + " B";
        if (b < 1048576) return Math.round(b / 1024) + " k";
        return (b / 1048576).toFixed(1) + " M";
    }
    function bytes(b) {
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB";
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB";
        return (b / 1073741824).toFixed(2) + " GB";
    }

    function parse(t) {
        const [stat, mem, net, route] = t.split("--\n");

        const c = stat.trim().split(/\s+/).slice(1).map(Number);
        const idle = c[3] + (c[4] || 0);
        const total = c.reduce((a, b) => a + b, 0);
        if (aero.prevCpu) {
            const dt = total - aero.prevCpu.total;
            aero.cpu = dt > 0 ? Math.max(0, 1 - (idle - aero.prevCpu.idle) / dt) : 0;
        }
        aero.prevCpu = { idle: idle, total: total };
        aero.cpuHist = push(aero.cpuHist, aero.cpu);

        const m = {};
        for (const l of mem.split("\n")) {
            const x = l.match(/^(\w+):\s+(\d+)/);
            if (x) m[x[1]] = Number(x[2]) * 1024;
        }
        aero.memTotal = m.MemTotal || 1;
        aero.memUsed = m.MemTotal - m.MemAvailable;
        aero.swapTotal = m.SwapTotal || 0;
        aero.swapUsed = m.SwapTotal - m.SwapFree;

        const dev = ((route || "").match(/ dev (\S+)/) || [])[1] || "";
        aero.iface = dev;
        let rx = 0, tx = 0;
        for (const l of net.split("\n")) {
            const x = l.trim().match(/^([^:]+):\s*(.*)$/);
            if (x && x[1] === dev) {
                const f = x[2].split(/\s+/).map(Number);
                rx = f[0]; tx = f[8];
            }
        }
        const now = Date.now();
        if (aero.prevNet && aero.prevNet.dev === dev && dev !== "") {
            const dt = (now - aero.prevT) / 1000;
            const dr = Math.max(0, rx - aero.prevNet.rx), dtx = Math.max(0, tx - aero.prevNet.tx);
            aero.down = dr / dt;
            aero.up = dtx / dt;
            aero.downTotal += dr;
            aero.upTotal += dtx;
            aero.downPeak = Math.max(aero.downPeak, aero.down);
            aero.upPeak = Math.max(aero.upPeak, aero.up);
        } else {
            aero.down = 0;
            aero.up = 0;
        }
        aero.prevNet = { dev: dev, rx: rx, tx: tx };
        aero.prevT = now;
        aero.downHist = push(aero.downHist, aero.down);
        aero.upHist = push(aero.upHist, aero.up);
    }

    Process {
        id: poll
        command: ["sh", "-c", "head -1 /proc/stat; echo --; cat /proc/meminfo; echo --; cat /proc/net/dev; echo --; ip route show default | head -1"]
        stdout: StdioCollector { onStreamFinished: aero.parse(this.text) }
    }
    Timer { interval: 1000; repeat: true; running: aero.on; triggeredOnStart: true; onTriggered: poll.running = true }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = (this.text.trim().split("\n")[1] || "").trim().split(/\s+/);
                if (f.length === 2) { aero.diskUsed = Number(f[0]); aero.diskTotal = Number(f[1]) || 1; }
            }
        }
    }
    Timer { interval: 30000; repeat: true; running: aero.on; triggeredOnStart: true; onTriggered: df.running = true }
}
