import Quickshell
import Quickshell.Io
import QtQuick

// emoji grid with search, categories and recents
Scope {
    id: emo

    property var all: []           // [emoji, name, keywords, category]
    property var recent: []
    property string query: ""
    property int cat: 0
    property int sel: 0

    readonly property var cats: ["recent", "all", "people", "animals", "nature", "food", "travel", "activity", "objects", "symbols", "flags"]
    readonly property int cols: 10

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (q !== "") {
            const words = q.split(/\s+/);
            return all.filter(e => words.every(w => e[1].includes(w) || e[2].includes(w)));
        }
        const c = cats[cat];
        if (c === "recent") return recent.map(r => all.find(e => e[0] === r)).filter(e => e);
        if (c === "all") return all;
        return all.filter(e => e[3] === c);
    }

    onQueryChanged: sel = 0
    onCatChanged: sel = 0

    function toggle(out) {
        if (win.open) { win.hide(); return; }
        cat = recent.length > 0 ? 0 : 1;
        sel = 0;
        win.show(out);
    }

    function pick(e) {
        if (!e) return;
        Quickshell.execDetached(["wl-copy", e[0]]);
        recent = [e[0]].concat(recent.filter(r => r !== e[0])).slice(0, 40);
        recentFile.setText(JSON.stringify(recent));
        win.hide();
    }

    FileView {
        path: Qt.resolvedUrl("emoji.json").toString().replace("file://", "")
        onLoaded: emo.all = JSON.parse(text()).map(e => [e[0], e[1].toLowerCase(), e[2].toLowerCase(), e[3]])
    }

    FileView {
        id: recentFile
        path: Theme.cacheDir + "/emoji-recent.json"
        printErrors: false
        onLoaded: { try { emo.recent = JSON.parse(text()); } catch (e) {} }
    }

    Overlay {
        id: win
        ns: "aroclip-emoji"
        cardWidth: 560
        cardHeight: 440

        SearchHeader {
            id: header
            title: "emoji"
            info: emo.shown.length + ""
            active: win.open
            onQueryChanged: emo.query = query
            onKeyPressed: (ev) => {
                const n = emo.shown.length;
                const ctrl = ev.modifiers & Qt.ControlModifier;
                if (ev.key === Qt.Key_Escape) win.hide();
                else if (ev.key === Qt.Key_Tab) emo.cat = (emo.cat + 1) % emo.cats.length;
                else if (ev.key === Qt.Key_Backtab) emo.cat = (emo.cat + emo.cats.length - 1) % emo.cats.length;
                else if (ev.key === Qt.Key_Right || (ctrl && ev.key === Qt.Key_L)) emo.sel = Math.min(emo.sel + 1, n - 1);
                else if (ev.key === Qt.Key_Left || (ctrl && ev.key === Qt.Key_H)) emo.sel = Math.max(emo.sel - 1, 0);
                else if (ev.key === Qt.Key_Down || (ctrl && ev.key === Qt.Key_J)) emo.sel = Math.min(emo.sel + emo.cols, n - 1);
                else if (ev.key === Qt.Key_Up || (ctrl && ev.key === Qt.Key_K)) emo.sel = Math.max(emo.sel - emo.cols, 0);
                else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) emo.pick(emo.shown[emo.sel]);
                else return;
                ev.accepted = true;
            }
        }

        // category chips
        Item {
            id: chips
            anchors { top: header.bottom; left: parent.left; right: parent.right; margins: 3 }
            height: 30
            opacity: emo.query === "" ? 1 : 0.35
            Behavior on opacity { NumberAnimation { duration: Theme.focusMs } }

            Row {
                id: chipRow
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 12
                Repeater {
                    model: emo.cats
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData
                        color: index === emo.cat ? Theme.text : Theme.dim
                        font { family: Theme.font; pixelSize: 11; bold: index === emo.cat }
                        Behavior on color { ColorAnimation { duration: Theme.focusMs } }
                        MouseArea { anchors.fill: parent; onClicked: { emo.cat = parent.index; header.query = ""; } }
                    }
                }
            }
            Rectangle {
                readonly property Item target: chipRow.children[emo.cat] ?? null
                x: chipRow.x + (target ? target.x : 0)
                width: target ? target.width : 0
                y: parent.height - 5
                height: 2; radius: 1
                color: Theme.accent
                Behavior on x { NumberAnimation { duration: Theme.focusMs * 1.4; easing.type: Easing.OutBack; easing.overshoot: 1.70158 * Theme.bounce } }
                Behavior on width { NumberAnimation { duration: Theme.focusMs * 1.4; easing.type: Easing.OutCubic } }
            }
        }

        GridView {
            id: grid
            anchors { top: chips.bottom; left: parent.left; right: parent.right; bottom: footer.top; margins: 9 }
            clip: true
            cellWidth: Math.floor(width / emo.cols)
            cellHeight: cellWidth
            model: emo.shown
            currentIndex: emo.sel
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.focusMs
            highlightFollowsCurrentItem: true
            preferredHighlightBegin: cellHeight
            preferredHighlightEnd: height - cellHeight
            highlightRangeMode: GridView.ApplyRange

            highlight: Rectangle {
                radius: Theme.radius
                color: Theme.frame
                border.width: 1
                border.color: Theme.accent
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                opacity: 0
                scale: 0.6
                Component.onCompleted: pop.start()
                SequentialAnimation {
                    id: pop
                    PauseAnimation { duration: Math.min(cell.index, 30) * 8 }
                    ParallelAnimation {
                        NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 180 * Theme.slow }
                        NumberAnimation { target: cell; property: "scale"; to: 1; duration: 260 * Theme.slow; easing.type: Easing.OutBack; easing.overshoot: 2 * Theme.bounce }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData[0]
                    color: Theme.text
                    font.pixelSize: cell.index === emo.sel ? 30 : 24
                    Behavior on font.pixelSize { NumberAnimation { duration: Theme.focusMs; easing.type: Easing.OutBack; easing.overshoot: 1.70158 * Theme.bounce } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: emo.sel = cell.index
                    onClicked: emo.pick(cell.modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: emo.shown.length === 0
                text: emo.query !== "" ? "no match" : emo.cats[emo.cat] === "recent" ? "nothing picked yet" : "loading"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 13 }
            }
        }

        Item {
            id: footer
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 3 }
            height: 30
            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: Theme.border }
            Text {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: parent.width * 0.55
                elide: Text.ElideRight
                text: emo.shown[emo.sel] ? emo.shown[emo.sel][1] : ""
                color: Theme.text
                font { family: Theme.font; pixelSize: 12 }
            }
            Text {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: "enter copy · tab category · esc close"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10 }
            }
        }
    }
}
