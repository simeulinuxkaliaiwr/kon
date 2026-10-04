import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// win7 flip 3d; on niri mod+Tab opens the overview instead
Scope {
    id: flip

    property bool open: false
    property var all: []   // kon-wm windows
    property var wins: []   // most recent first
    property var next: []   // shown after the screen grab
    property int cur: 0                 // the one in front
    property var mru: []                // window ids, most recent first
    property int rev: 0   // bump to reload images
    readonly property string grab: Theme.cacheDir + "/flip-screen.ppm"

    // open, or go to the next window
    function toggle() {
        if (!Aero.on || Theme.wm === "niri") { overview.running = true; return; }
        if (open) { step(1); return; }
        if (!query.running && !shot.running) query.running = true;
    }
    function step(d) { if (wins.length) cur = (cur + d + wins.length) % wins.length; }
    function close() { open = false; }
    function pick() {
        const w = wins[cur];
        close();
        const t = w ? toplevelOf(w) : null;
        if (t) t.activate();
    }

    // match by app and title, else by order
    function toplevelOf(w) {
        const same = ToplevelManager.toplevels.values.filter(t => t.appId === w.app_id);
        const exact = same.find(t => t.title === w.title);
        if (exact) return exact;
        return same[flip.all.filter(x => x.app_id === w.app_id).indexOf(w)] ?? null;
    }

    // track focus order
    Process {
        id: events
        running: Aero.on
        command: [Theme.bin + "kon-wm", "events"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^focus (\d+) /);
                if (!m) return;
                const id = Number(m[1]);
                flip.mru = [id].concat(flip.mru.filter(x => x !== id)).slice(0, 64);
            }
        }
        onRunningChanged: if (!running && Aero.on) again.restart()
    }
    Timer { id: again; interval: 2000; onTriggered: events.running = Aero.on }

    Process {
        id: query
        command: [Theme.bin + "kon-wm", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                let a;
                try { a = JSON.parse(this.text); } catch (e) { return; }
                a = a.filter(w => w.state !== "scratchpad" && w.width > 0 && w.height > 0);
                if (!a.length) return;
                const rank = w => w.focused ? -1 : (flip.mru.indexOf(w.id) < 0 ? 1e6 + w.id : flip.mru.indexOf(w.id));
                flip.all = a;
                flip.next = a.slice().sort((x, y) => rank(x) - rank(y));
                shot.running = true;
            }
        }
    }
    // grab the screen first
    Process {
        id: shot
        command: ["grim", "-t", "ppm", flip.grab]
        onExited: {
            flip.rev++;
            flip.wins = flip.next;
            flip.cur = flip.wins.length > 1 ? 1 : 0;     // a quick tap swaps the last two
            flip.open = true;
        }
    }
    Process { id: overview; command: [Theme.bin + "kon-wm", "overview"] }

    PanelWindow {
        id: win
        visible: flip.open
        screen: Theme.screenFor(flip.wins.length ? flip.wins[0].output : "")
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "aero-flip"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) stage.forceActiveFocus()

        readonly property real sw: screen ? screen.width : width
        readonly property real sh: screen ? screen.height : height

        // dimmed desktop
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.02, 0.06, 0.13, 0.50) }
                GradientStop { position: 1; color: Qt.rgba(0.01, 0.03, 0.07, 0.70) }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: flip.close()
            onWheel: w => flip.step(w.angleDelta.y < 0 ? 1 : -1)
        }

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_Down) flip.step(1);
                else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left || e.key === Qt.Key_Up) flip.step(-1);
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) flip.pick();
                else if (e.key === Qt.Key_Escape) flip.close();
                else return;
                e.accepted = true;
            }
            // releasing mod picks
            Keys.onReleased: e => {
                if (e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R || e.key === Qt.Key_Meta) {
                    flip.pick();
                    e.accepted = true;
                }
            }

            Repeater {
                model: flip.wins

                Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property int n: flip.wins.length
                    readonly property int k: (index - flip.cur + n) % n     // 0 is the front
                    property int lastK: -1

                    // fit to half the screen
                    readonly property real fit: Math.min(win.sw * 0.5 / modelData.width, win.sh * 0.56 / modelData.height)
                    width: modelData.width * fit
                    height: modelData.height * fit

                    property real cx: 0
                    property real cy: 0
                    property real s: 1
                    property real o: 0
                    x: cx - width / 2
                    y: cy - height / 2
                    scale: s
                    opacity: o
                    z: n - k
                    Behavior on cx { id: bx; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on cy { id: by; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on s { id: bs; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on o { id: bo; NumberAnimation { duration: 220 } }

                    // stack goes up and right
                    function place() {
                        const jump = lastK >= 0 && Math.abs(k - lastK) > 1;
                        const first = lastK < 0;
                        for (const b of [bx, by, bs]) b.enabled = !jump && !first;
                        cx = win.sw * 0.40 + k * win.sw * 0.05;
                        cy = win.sh * 0.57 - k * win.sh * 0.045;
                        s = Math.max(0.35, 1 - k * 0.07);
                        for (const b of [bx, by, bs]) b.enabled = true;
                        if (jump || first) { bo.enabled = false; o = 0; bo.enabled = true; }
                        o = k > 7 ? 0 : 1 - k * 0.09;
                        lastK = k;
                    }
                    onKChanged: place()
                    Component.onCompleted: place()

                    transform: Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: -26
                    }

                    // glass frame
                    Rectangle {
                        anchors { fill: parent; margins: -7 }
                        radius: 8
                        border.color: Qt.rgba(1, 1, 1, card.k === 0 ? 0.75 : 0.45)
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(0.80, 0.88, 0.97, 0.55) }
                            GradientStop { position: 1; color: Qt.rgba(0.55, 0.70, 0.88, 0.40) }
                        }
                    }

                    // no picture yet: icon and title
                    Rectangle {
                        anchors.fill: parent
                        visible: shotImg.status !== Image.Ready && !live.hasContent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#2b3a4c" }
                            GradientStop { position: 1; color: "#141c26" }
                        }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: Math.min(parent.width, parent.height) * 0.3
                            source: Quickshell.iconPath(card.modelData.app_id, "application-x-executable")
                        }
                        Text {
                            anchors { bottom: parent.bottom; bottomMargin: 14; horizontalCenter: parent.horizontalCenter }
                            width: parent.width - 24
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: card.modelData.title
                            color: Aero.ink
                            font { family: Aero.font; pixelSize: 16 }
                        }
                    }

                    Image {
                        id: shotImg
                        anchors.fill: parent
                        cache: false
                        smooth: true
                        mipmap: true
                        source: card.modelData.visible
                            ? "file://" + flip.grab + "?" + flip.rev
                            : "file://" + Theme.cacheDir + "/thumbs/" + card.modelData.id + ".png?" + flip.rev
                        sourceClipRect: card.modelData.visible
                            ? Qt.rect(card.modelData.x, card.modelData.y, card.modelData.width, card.modelData.height)
                            : undefined
                    }

                    ScreencopyView {
                        id: live
                        anchors.fill: parent
                        captureSource: flip.open ? flip.toplevelOf(card.modelData) : null
                        live: true
                    }

                    // shine
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.20) }
                            GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: { flip.cur = card.index; flip.pick(); }
                    }
                }
            }
        }

        // title of the front window
        Rectangle {
            visible: flip.wins.length > 0
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: win.sh * 0.08 }
            width: Math.min(win.sw * 0.5, label.implicitWidth + icon.width + 44)
            height: 38
            radius: 19
            border.color: Qt.rgba(1, 1, 1, 0.45)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.85, 0.92, 1, 0.42) }
                GradientStop { position: 0.49; color: Qt.rgba(0.60, 0.75, 0.92, 0.32) }
                GradientStop { position: 0.5; color: Qt.rgba(0.30, 0.48, 0.70, 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(0.40, 0.62, 0.86, 0.40) }
            }
            readonly property var front: flip.wins[flip.cur] ?? null
            IconImage {
                id: icon
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                implicitSize: 22
                source: parent.front ? Quickshell.iconPath(parent.front.app_id, "application-x-executable") : ""
            }
            Text {
                id: label
                anchors { left: icon.right; leftMargin: 10; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                text: parent.front ? parent.front.title : ""
                elide: Text.ElideRight
                color: "white"
                style: Text.Raised
                styleColor: "#80000000"
                font { family: Aero.font; pixelSize: 15 }
            }
        }
    }
}
