import Quickshell
import Quickshell.Io
import QtQuick

// clipboard history from cliphist
Scope {
    id: cb

    property var entries: []
    property string query: ""
    property int sel: 0
    property var thumbs: ({})

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        const out = q === "" ? entries : entries.filter(e => e.text.toLowerCase().includes(q));
        return out.slice(0, 150);
    }

    onQueryChanged: sel = 0

    function toggle(out) {
        if (win.open) { win.hide(); return; }
        sel = 0;
        lister.running = true;
        win.show(out);
    }

    function pick(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", e.id]);
        win.hide();
    }

    function remove(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", e.id]);
        entries = entries.filter(x => x.id !== e.id);
        sel = Math.min(sel, Math.max(0, filtered.length - 1));
    }

    function thumb(e) {
        if (thumbs[e.id] !== undefined) return;
        const t = Object.assign({}, thumbs);
        t[e.id] = "";
        thumbs = t;
        thumbJob.createObject(cb, { entry: e });
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const img = /^\[\[ binary data (.+?) (png|jpe?g|webp|gif|bmp) (\d+x\d+) \]\]$/i;
                cb.entries = this.text.split("\n").filter(l => l.length > 0).map(l => {
                    const tab = l.indexOf("\t");
                    const text = l.slice(tab + 1);
                    const m = text.match(img);
                    return {
                        id: l.slice(0, tab),
                        text: m ? "image " + m[3] : text,
                        image: !!m,
                        ext: m ? m[2].toLowerCase() : "",
                        meta: m ? m[2].toUpperCase() + " · " + m[1] : ""
                    };
                });
            }
        }
    }

    // decode images once
    Component {
        id: thumbJob
        Process {
            id: job
            property var entry
            readonly property string path: Theme.cacheDir + "/" + entry.id + "." + entry.ext
            command: ["sh", "-c", 'mkdir -p "$(dirname "$2")"; [ -s "$2" ] || cliphist decode "$1" > "$2"', "sh", entry.id, path]
            running: true
            onExited: {
                const t = Object.assign({}, cb.thumbs);
                t[entry.id] = "file://" + path;
                cb.thumbs = t;
                job.destroy();
            }
        }
    }

    Overlay {
        id: win
        ns: "aroclip"

        SearchHeader {
            id: header
            title: "clipboard"
            info: cb.filtered.length + (cb.filtered.length === 1 ? " item" : " items")
            active: win.open
            onQueryChanged: cb.query = query
            onKeyPressed: (ev) => {
                const n = cb.filtered.length;
                const ctrl = ev.modifiers & Qt.ControlModifier;
                if (ev.key === Qt.Key_Escape) win.hide();
                else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab || (ctrl && ev.key === Qt.Key_J))
                    cb.sel = Math.min(cb.sel + 1, n - 1);
                else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab || (ctrl && ev.key === Qt.Key_K))
                    cb.sel = Math.max(cb.sel - 1, 0);
                else if (ev.key === Qt.Key_PageDown) cb.sel = Math.min(cb.sel + 8, n - 1);
                else if (ev.key === Qt.Key_PageUp) cb.sel = Math.max(cb.sel - 8, 0);
                else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) cb.pick(cb.filtered[cb.sel]);
                else if (ev.key === Qt.Key_Delete || (ctrl && ev.key === Qt.Key_D)) cb.remove(cb.filtered[cb.sel]);
                else return;
                ev.accepted = true;
            }
        }

        ListView {
            id: list
            anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: hint.top; margins: 9 }
            clip: true
            spacing: 4
            model: cb.filtered
            currentIndex: cb.sel
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.focusMs
            highlightMoveVelocity: -1
            highlightResizeDuration: Theme.focusMs
            preferredHighlightBegin: height * 0.3
            preferredHighlightEnd: height * 0.7
            highlightRangeMode: ListView.ApplyRange

            highlight: Rectangle {
                radius: Theme.radius
                color: Theme.frame
                border.width: 1
                border.color: Theme.accent
                Rectangle {
                    width: 3; radius: 1.5
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 5 }
                    color: Theme.accent
                }
            }

            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 140 * Theme.slow }
                NumberAnimation { property: "x"; to: 40; duration: 140 * Theme.slow; easing.type: Easing.InCubic }
            }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: Theme.focusMs; easing.type: Easing.OutCubic }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === cb.sel
                width: list.width
                height: modelData.image ? 76 : 36

                opacity: 0
                transform: Translate { id: shift; y: 10 }
                Component.onCompleted: {
                    if (modelData.image) cb.thumb(modelData);
                    enter.start();
                }
                SequentialAnimation {
                    id: enter
                    PauseAnimation { duration: Math.min(row.index, 12) * 18 }
                    ParallelAnimation {
                        NumberAnimation { target: row; property: "opacity"; to: 1; duration: 220 * Theme.slow; easing.type: Easing.OutCubic }
                        NumberAnimation { target: shift; property: "y"; to: 0; duration: 260 * Theme.slow; easing.type: Easing.OutBack; easing.overshoot: 1.70158 * Theme.bounce }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: cb.sel = row.index
                    onClicked: cb.pick(row.modelData)
                }

                Image {
                    id: pic
                    visible: row.modelData.image
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    width: 110; height: 62
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(220, 124)
                    source: row.modelData.image ? (cb.thumbs[row.modelData.id] ?? "") : ""
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 * Theme.slow } }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 3
                        border.width: 1
                        border.color: Theme.border
                    }
                }

                Column {
                    anchors {
                        left: row.modelData.image ? pic.right : parent.left
                        leftMargin: row.modelData.image ? 12 : 16
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        width: parent.width
                        text: row.modelData.text.replace(/\s+/g, " ").trim()
                        color: row.current ? Theme.text : Qt.darker(Theme.text, 1.25)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font { family: Theme.font; pixelSize: 13 }
                        Behavior on color { ColorAnimation { duration: Theme.focusMs } }
                    }
                    Text {
                        visible: row.modelData.image
                        text: row.modelData.meta
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: cb.filtered.length === 0 && !lister.running
                text: cb.query === "" ? "nothing copied yet" : "no match"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 13 }
            }
        }

        Text {
            id: hint
            anchors { bottom: parent.bottom; bottomMargin: 8; horizontalCenter: parent.horizontalCenter }
            text: "enter copy · del remove · esc close"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 10 }
        }
    }
}
