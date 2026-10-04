import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import QtQuick

// win7 style taskbar
Scope {
    id: bar

    property var launcher: null

    // desktop entry ids, left to right
    property var pinned: ["firefox", "org.qutebrowser.qutebrowser", "foot", "steam"]

    property var workspaces: []
    property string wifi: ""
    property int signal: -1
    property bool ethernet: false

    readonly property int h: 40

    // one button per app
    function keyOf(appId) {
        const e = DesktopEntries.heuristicLookup(appId);
        return (e ? e.id : appId).toLowerCase();
    }
    function iconOf(key) {
        const e = DesktopEntries.byId(key) ?? DesktopEntries.heuristicLookup(key);
        return Quickshell.iconPath(e?.icon ?? key, "application-x-executable");
    }
    function launch(key) {
        const e = DesktopEntries.byId(key) ?? DesktopEntries.heuristicLookup(key);
        if (e) e.execute();
    }

    // window previews, cropped with grim (not on niri)
    property var windows: []            // kon-wm windows
    property int snapRev: 0   // bump to reload thumbnails
    property bool peeking: false   // don't snap while a flyout is open
    property bool snapNow: false
    property bool snapAgain: false
    readonly property string thumbs: Theme.cacheDir + "/thumbs"

    // match by app and title, else by order
    function winOf(t) {
        const same = bar.windows.filter(w => w.app_id === t.appId);
        const exact = same.find(w => w.title === t.title);
        if (exact) return exact;
        const peers = ToplevelManager.toplevels.values.filter(x => x.appId === t.appId);
        return same[peers.indexOf(t)] ?? null;
    }
    function thumbOf(t) {
        const w = bar.winOf(t);
        return w ? "file://" + bar.thumbs + "/" + w.id + ".png?" + bar.snapRev : "";
    }
    function refresh(now) {
        if (now) bar.snapNow = true;
        winQuery.running = true;
    }
    function snap() {
        if (snapProc.running) { bar.snapAgain = true; return; }
        if (bar.peeking) return;
        // skip windows under a fullscreen one
        const full = bar.windows.filter(w => w.visible && w.fullscreen).map(w => w.output);
        const args = [];
        for (const w of bar.windows)
            if (w.visible && w.width > 0 && w.height > 0 && (w.fullscreen || !full.includes(w.output)))
                args.push(String(w.id), w.x + "," + w.y + " " + w.width + "x" + w.height);
        snapProc.command = ["sh", "-c", snapScript, "sh", bar.thumbs, bar.windows.map(w => w.id).join(" ")].concat(args);
        snapProc.running = true;
    }
    // args: dir, live ids, then id/geometry pairs
    readonly property string snapScript: 'dir=$1; keep=" $2 "; shift 2; mkdir -p "$dir"
for f in "$dir"/*.png; do [ -e "$f" ] || continue; id=${f##*/}; id=${id%.png}
  case "$keep" in *" $id "*) ;; *) rm -f "$f" ;; esac; done
while [ $# -ge 2 ]; do grim -s 0.3 -l 1 -g "$2" "$dir/$1.tmp" 2>/dev/null && mv -f "$dir/$1.tmp" "$dir/$1.png"; shift 2; done'

    Process {
        id: winQuery
        command: [Theme.bin + "kon-wm", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { bar.windows = JSON.parse(this.text); } catch (e) { return; }
                if (bar.snapNow) { bar.snapNow = false; bar.snap(); }
                else snapSoon.restart();
            }
        }
    }
    // wait for animations
    Timer { id: snapSoon; interval: 700; onTriggered: bar.snap() }
    Process {
        id: snapProc
        onExited: {
            bar.snapRev++;
            if (bar.snapAgain) { bar.snapAgain = false; bar.snap(); }
        }
    }

    Process {
        id: wsQuery
        command: [Theme.bin + "kon-wm", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: { try { bar.workspaces = JSON.parse(this.text); } catch (e) {} }
        }
    }
    Timer { id: wsSoon; interval: 40; onTriggered: { wsQuery.running = true; bar.refresh(false); } }
    Timer { interval: 3000; repeat: true; running: Aero.on; triggeredOnStart: true; onTriggered: wsQuery.running = true }
    Process {
        id: wsEvents
        running: Aero.on
        command: [Theme.bin + "kon-wm", "events"]
        stdout: SplitParser { onRead: wsSoon.restart() }
    }

    Process {
        id: netQuery
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE dev; echo --; nmcli -t -f IN-USE,SIGNAL,SSID dev wifi list --rescan no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [devs, nets] = this.text.split("--\n");
                bar.ethernet = /^ethernet:connected$/m.test(devs ?? "");
                const cur = (nets ?? "").split("\n").find(l => l.startsWith("*:"));
                if (cur) {
                    const f = cur.split(":");
                    bar.signal = parseInt(f[1]);
                    bar.wifi = f.slice(2).join(":");
                } else { bar.signal = -1; bar.wifi = ""; }
            }
        }
    }
    Timer { interval: 10000; repeat: true; running: Aero.on; triggeredOnStart: true; onTriggered: netQuery.running = true }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Variants {
        model: Aero.on ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { bottom: true; left: true; right: true }
            implicitHeight: bar.h
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: bar.h
            WlrLayershell.namespace: "aero-taskbar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property var ws: bar.workspaces.filter(w => w.output === modelData.name)
            readonly property var apps: ToplevelManager.toplevels.values.filter(t => t.screens.includes(modelData))

            // pins first, then running apps
            readonly property var groups: {
                const out = bar.pinned.map(k => ({ key: k, windows: [] }));
                for (const t of apps) {
                    const k = bar.keyOf(t.appId);
                    let g = out.find(x => x.key === k);
                    if (!g) { g = { key: k, windows: [] }; out.push(g); }
                    g.windows.push(t);
                }
                return out;
            }

            // tooltip
            PopupWindow {
                id: tip
                property Item target: null
                property string text: ""
                visible: target !== null && text !== ""
                color: "transparent"
                anchor.item: target
                anchor.rect.y: -6
                anchor.rect.width: target ? target.width : 0
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Top
                implicitWidth: Math.min(tipLabel.implicitWidth + 14, 420)
                implicitHeight: tipLabel.implicitHeight + 8
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    border.color: "#767676"
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ffffff" }
                        GradientStop { position: 1; color: "#e4e5f0" }
                    }
                    Text {
                        id: tipLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 406)
                        elide: Text.ElideRight
                        text: tip.text
                        color: "#3c3c3c"
                        font { family: Aero.font; pixelSize: 12 }
                    }
                }
            }
            Timer { id: tipDelay; interval: 450; property Item next; property string nextText; onTriggered: { tip.text = nextText; tip.target = next; } }
            function hint(item, text) { tipDelay.next = item; tipDelay.nextText = text; tipDelay.restart(); }
            function unhint() { tipDelay.stop(); tip.target = null; }

            // thumbnail flyout
            PopupWindow {
                id: peek
                property Item target: null
                readonly property var windows: target ? target.windows : []
                readonly property int n: Math.max(1, windows.length)
                readonly property real cardW: Math.min(212, (win.width - 40) / n - 4)
                readonly property real cardH: cardW * 0.62 + 26
                visible: target !== null && windows.length > 0
                onVisibleChanged: bar.peeking = visible
                color: "transparent"
                anchor.item: target
                anchor.rect.y: -6
                anchor.rect.width: target ? target.width : 0
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Top
                implicitWidth: n * (cardW + 4) + 12
                implicitHeight: cardH + 16

                HoverHandler { id: peekHover; onHoveredChanged: win.peekHoverChanged() }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Aero.panel
                    border.color: Aero.panelEdge
                    Rectangle {
                        anchors { fill: parent; margins: 1 }
                        radius: 5
                        color: "transparent"
                        border.color: Qt.rgba(0, 0, 0, 0.4)
                    }
                }

                Row {
                    x: 8; y: 8
                    spacing: 4
                    Repeater {
                        model: peek.windows
                        Item {
                            id: card
                            required property var modelData
                            width: peek.cardW; height: peek.cardH
                            HoverHandler { id: cardHover }

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                visible: cardHover.hovered || card.modelData.activated
                                border.color: Qt.rgba(1, 1, 1, cardHover.hovered ? 0.6 : 0.35)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, cardHover.hovered ? 0.30 : 0.16) }
                                    GradientStop { position: 1; color: Qt.rgba(0.6, 0.85, 1, cardHover.hovered ? 0.22 : 0.08) }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: (m) => {
                                    if (m.button === Qt.MiddleButton) card.modelData.close();
                                    else { card.modelData.activate(); win.unpeek(); }
                                }
                            }

                            IconImage {
                                id: cardIcon
                                x: 5; y: 5
                                implicitSize: 16
                                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(card.modelData.appId)?.icon ?? card.modelData.appId, "application-x-executable")
                            }
                            Text {
                                anchors { left: cardIcon.right; leftMargin: 5; right: closeBtn.left; rightMargin: 4; verticalCenter: cardIcon.verticalCenter }
                                text: card.modelData.title || card.modelData.appId
                                elide: Text.ElideRight
                                color: Aero.ink
                                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                                font { family: Aero.font; pixelSize: 12 }
                            }
                            // close button
                            Rectangle {
                                id: closeBtn
                                anchors { right: parent.right; rightMargin: 4; verticalCenter: cardIcon.verticalCenter }
                                width: 20; height: 16; radius: 3
                                visible: cardHover.hovered
                                border.color: Qt.rgba(0.3, 0.02, 0, 0.8)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: closeMouse.containsMouse ? "#f08d7e" : "#d9877b" }
                                    GradientStop { position: 0.5; color: closeMouse.containsMouse ? "#e5503a" : "#c5452f" }
                                    GradientStop { position: 1; color: closeMouse.containsMouse ? "#f2a04d" : "#d57a3c" }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: "white"
                                    font { pixelSize: 10; bold: true }
                                }
                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: card.modelData.close()
                                }
                            }

                            Item {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: cardIcon.bottom; margins: 5 }
                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    source: bar.thumbOf(card.modelData)
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    smooth: true
                                    mipmap: true
                                }
                                // no thumbnail yet
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: thumb.status !== Image.Ready
                                    implicitSize: 48
                                    source: cardIcon.source
                                }
                            }
                        }
                    }
                }
            }
            Timer { id: peekDelay; interval: 400; property Item next; onTriggered: peek.target = next }
            Timer { id: peekClose; interval: 300; onTriggered: peek.target = null }
            function showPeek(item) {
                peekClose.stop();
                bar.refresh(true);
                // already open, just move it
                if (peek.target) { peekDelay.stop(); peek.target = item; return; }
                peekDelay.next = item;
                peekDelay.restart();
            }
            function leavePeek() { peekDelay.stop(); if (!peekHover.hovered) peekClose.restart(); }
            function peekHoverChanged() { if (peekHover.hovered) peekClose.stop(); else peekClose.restart(); }
            function unpeek() { peekDelay.stop(); peekClose.stop(); peek.target = null; }

            // glass
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0.62, 0.74, 0.86, 0.42) }
                    GradientStop { position: 0.48; color: Qt.rgba(0.30, 0.42, 0.56, 0.38) }
                    GradientStop { position: 0.52; color: Qt.rgba(0.10, 0.18, 0.28, 0.52) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.12, 0.20, 0.62) }
                }
            }
            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: Qt.rgba(0, 0, 0, 0.45) }
            Rectangle { anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right } height: 1; color: Qt.rgba(1, 1, 1, 0.38) }

            // start orb
            Item {
                id: orb
                x: 6
                width: 48; height: bar.h
                Rectangle {
                    id: orbGlow
                    anchors.centerIn: parent
                    width: 46; height: 46; radius: 23
                    color: "transparent"
                    opacity: orbMouse.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Qt.rgba(0.55, 0.85, 1, 0.0) }
                        GradientStop { position: 0.5; color: Qt.rgba(0.55, 0.85, 1, 0.35) }
                        GradientStop { position: 1; color: Qt.rgba(0.55, 0.85, 1, 0.0) }
                    }
                }
                Rectangle {
                    id: ball
                    anchors.centerIn: parent
                    width: 36; height: 36; radius: 18
                    border.width: 1
                    border.color: Qt.rgba(0.02, 0.10, 0.20, 0.9)
                    scale: orbMouse.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: orbMouse.containsMouse ? "#9fe0ff" : "#6fb6e8" }
                        GradientStop { position: 0.5; color: orbMouse.containsMouse ? "#2f8fd8" : "#1d6bb0" }
                        GradientStop { position: 0.51; color: orbMouse.containsMouse ? "#0f5fa8" : "#0b4680" }
                        GradientStop { position: 1.0; color: orbMouse.containsMouse ? "#5fd0ff" : "#2b8fd0" }
                    }
                    // gloss
                    Rectangle {
                        x: 5; y: 2
                        width: parent.width - 10; height: parent.height / 2 - 2
                        radius: height / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.75) }
                            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        text: ""
                        color: "white"
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font { family: Theme.icons; pixelSize: 17 }
                    }
                }
                MouseArea {
                    id: orbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.launcher?.toggle(win.modelData.name)
                }
            }

            // apps
            Row {
                id: tasks
                anchors { left: orb.right; leftMargin: 8; top: parent.top; topMargin: 2 }
                spacing: 2

                Repeater {
                    model: win.groups
                    Item {
                        id: task
                        required property var modelData
                        readonly property var windows: modelData.windows
                        readonly property bool running: windows.length > 0
                        readonly property bool active: windows.some(w => w.activated)
                        width: 56; height: bar.h - 3

                        // stacked look for multiple windows
                        Rectangle {
                            visible: task.windows.length > 1
                            x: 3; y: 1
                            width: parent.width - 3; height: parent.height - 2
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.28)
                        }
                        Rectangle {
                            id: face
                            width: parent.width - (task.windows.length > 1 ? 3 : 0); height: parent.height - 2
                            y: 1
                            radius: 3
                            visible: task.running || taskMouse.containsMouse
                            border.color: task.active ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(1, 1, 1, 0.38)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, task.active ? 0.45 : taskMouse.containsMouse ? 0.32 : 0.20) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, task.active ? 0.22 : 0.08) }
                                GradientStop { position: 0.51; color: Qt.rgba(1, 1, 1, task.active ? 0.12 : 0.02) }
                                GradientStop { position: 1.0; color: Qt.rgba(0.6, 0.85, 1, task.active ? 0.35 : taskMouse.containsMouse ? 0.25 : 0.08) }
                            }
                            // inner line
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 2
                                color: "transparent"
                                border.color: Qt.rgba(0, 0, 0, 0.35)
                            }
                        }
                        IconImage {
                            anchors.centerIn: face
                            implicitSize: 28
                            source: bar.iconOf(task.modelData.key)
                            scale: taskMouse.pressed ? 0.88 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                        }
                        MouseArea {
                            id: taskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            // flyout for running apps, tooltip for pins
                            onEntered: {
                                if (task.running) { win.showPeek(task); return; }
                                win.hint(task, (DesktopEntries.byId(task.modelData.key) ?? DesktopEntries.heuristicLookup(task.modelData.key))?.name ?? task.modelData.key);
                            }
                            onExited: { win.unhint(); win.leavePeek(); }
                            onClicked: (m) => {
                                win.unhint();
                                win.unpeek();
                                const w = task.windows;
                                if (m.button === Qt.MiddleButton || w.length === 0) { bar.launch(task.modelData.key); return; }
                                // clicking the active one minimizes it
                                if (w.length === 1 && w[0].activated && !w[0].minimized) { w[0].minimized = true; return; }
                                // cycle through its windows
                                const i = w.findIndex(x => x.activated);
                                w[(i + 1) % w.length].activate();
                            }
                        }
                    }
                }
            }

            // workspaces, tray, clock
            Row {
                id: right
                anchors { right: sliver.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 6

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: win.ws
                        Rectangle {
                            required property var modelData
                            width: 18; height: 18
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            border.color: modelData.visible ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.25)
                            color: modelData.visible ? Qt.rgba(0.55, 0.8, 1, 0.45) : wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.index
                                color: parent.modelData.windows > 0 || parent.modelData.visible ? Aero.ink : Aero.inkDim
                                font { family: Aero.font; pixelSize: 10; bold: parent.modelData.visible }
                            }
                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached([Theme.bin + "kon-wm", "workspace", String(parent.modelData.index)])
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 26; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.18) }

                Repeater {
                    model: SystemTray.items
                    Item {
                        id: trayItem
                        required property var modelData
                        width: 20; height: bar.h
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 16
                            source: trayItem.modelData.icon
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onEntered: win.hint(trayItem, trayItem.modelData.tooltipTitle || trayItem.modelData.title)
                            onExited: win.unhint()
                            onClicked: (m) => {
                                win.unhint();
                                const it = trayItem.modelData;
                                if (m.button === Qt.MiddleButton) it.secondaryActivate();
                                else if (m.button === Qt.RightButton || it.onlyMenu) {
                                    if (it.hasMenu) {
                                        const p = trayItem.mapToItem(null, 0, 0);
                                        it.display(win, p.x, p.y - 4);
                                    }
                                } else it.activate();
                            }
                        }
                    }
                }

                // volume
                Item {
                    id: vol
                    width: 22; height: bar.h
                    Text {
                        anchors.centerIn: parent
                        text: !bar.sink || bar.sink.muted ? "󰝟" : bar.sink.volume < 0.34 ? "󰕿" : bar.sink.volume < 0.67 ? "󰖀" : "󰕾"
                        color: Aero.ink
                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font { family: Theme.icons; pixelSize: 16 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: win.hint(vol, bar.sink ? (bar.sink.muted ? "muted" : "Speakers: " + Math.round(bar.sink.volume * 100) + "%") : "no audio")
                        onExited: win.unhint()
                        onClicked: (m) => Quickshell.execDetached(m.button === Qt.RightButton ? ["pavucontrol"] : [Theme.bin + "aroclip", "vol", "mute"])
                        onWheel: (w) => Quickshell.execDetached([Theme.bin + "aroclip", "vol", w.angleDelta.y > 0 ? "up" : "down"])
                    }
                }

                // network
                Item {
                    id: net
                    width: 22; height: bar.h
                    Text {
                        anchors.centerIn: parent
                        text: bar.ethernet ? "󰈀" : bar.signal < 0 ? "󰤭" : ["󰤟", "󰤢", "󰤥", "󰤨"][Math.min(3, Math.floor(bar.signal / 25))]
                        color: !bar.ethernet && bar.signal < 0 ? Aero.inkDim : Aero.ink
                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font { family: Theme.icons; pixelSize: 16 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: win.hint(net, bar.ethernet ? "Ethernet: Internet access" : bar.signal < 0 ? "Not connected" : bar.wifi + "\nInternet access · " + bar.signal + "%")
                        onExited: win.unhint()
                        onClicked: (m) => Quickshell.execDetached(m.button === Qt.RightButton ? ["nm-connection-editor"] : ["foot", "-e", "nmtui"])
                    }
                }

                // battery
                Row {
                    id: batt
                    readonly property var dev: UPower.displayDevice
                    readonly property real pct: dev ? (dev.percentage > 1 ? dev.percentage / 100 : dev.percentage) : 0
                    readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
                    visible: dev && dev.isLaptopBattery
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: batt.charging ? "󰂄" : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.min(10, Math.round(batt.pct * 10))]
                        color: !batt.charging && batt.pct <= 0.15 ? "#ff6a5a" : batt.charging ? "#8be06a" : Aero.ink
                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font { family: Theme.icons; pixelSize: 16 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(batt.pct * 100) + "%"
                        color: Aero.ink
                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font { family: Aero.font; pixelSize: 12 }
                    }
                }

                // clock
                Item {
                    id: clockBox
                    width: Math.max(timeText.implicitWidth, dateText.implicitWidth) + 16
                    height: bar.h
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 3
                        visible: clockMouse.containsMouse || cal.open
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                    }
                    Column {
                        anchors.centerIn: parent
                        Text {
                            id: timeText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: clock.date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                            color: Aero.ink
                            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                            font { family: Aero.font; pixelSize: 12 }
                        }
                        Text {
                            id: dateText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(clock.date, "dd/MM/yyyy")
                            color: Aero.ink
                            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                            font { family: Aero.font; pixelSize: 12 }
                        }
                    }
                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.hint(clockBox, clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat))
                        onExited: win.unhint()
                        onClicked: { win.unhint(); cal.toggle(); }
                    }
                }
            }

            Calendar { id: cal; anchorItem: clockBox; above: true }

            // show desktop toggles the gadgets
            Rectangle {
                id: sliver
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 2 }
                width: 14
                border.color: Qt.rgba(1, 1, 1, 0.3)
                color: sliverMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                MouseArea {
                    id: sliverMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: win.hint(sliver, Aero.widgetsHidden ? "Show gadgets" : "Hide gadgets")
                    onExited: win.unhint()
                    onClicked: { win.unhint(); Aero.widgetsHidden = !Aero.widgetsHidden; }
                }
            }
        }
    }
}
