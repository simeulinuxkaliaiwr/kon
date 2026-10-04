import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// win7 start menu
Scope {
    id: sm

    property var power: null

    property bool open: false
    property string output: ""
    property string query: ""
    property bool all: false            // "All Programs" instead of the frequent list
    property int sel: 0
    property var counts: ({})

    readonly property string user: Quickshell.env("USER")
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property var list: {
        const q = query.trim().toLowerCase();
        const uses = e => counts[e.id] ?? 0;
        if (q !== "")
            return apps.map(e => ({ e: e, s: score(e, q) }))
                .filter(r => r.s > 0)
                .sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name))
                .map(r => r.e).slice(0, 40);
        if (all) return apps.slice().sort((a, b) => a.name.localeCompare(b.name));
        return apps.filter(e => uses(e) > 0).sort((a, b) => uses(b) - uses(a)).slice(0, 10);
    }

    // right side link
    component Place: Item {
        id: item
        property string label
        property bool bold: false
        signal activated()
        width: parent.width; height: 30
        Rectangle {
            anchors.fill: parent
            radius: 3
            visible: placeMouse.containsMouse
            border.color: Qt.rgba(1, 1, 1, 0.55)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.30) }
                GradientStop { position: 1; color: Qt.rgba(0.6, 0.85, 1, 0.20) }
            }
        }
        Text {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: item.label
            color: "white"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
            font { family: Aero.font; pixelSize: 13; bold: item.bold }
        }
        MouseArea {
            id: placeMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: item.activated()
        }
    }

    function score(e, q) {
        const n = e.name.toLowerCase();
        if (n === q) return 100;
        if (n.startsWith(q)) return 80;
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 60;
        if (n.includes(q)) return 45;
        if ([e.genericName, e.comment, (e.keywords ?? []).join(" "), e.id].join(" ").toLowerCase().includes(q)) return 30;
        return 0;
    }

    function toggle(out) {
        if (open) { open = false; return; }
        output = out;
        query = "";
        all = false;
        sel = 0;
        usage.reload();
        open = true;
    }

    function launch(e) {
        if (!e) return;
        const c = Object.assign({}, counts);
        c[e.id] = (c[e.id] ?? 0) + 1;
        counts = c;
        usage.setText(JSON.stringify(counts));
        if (e.runInTerminal) Quickshell.execDetached(["foot", "-e"].concat(e.command));
        else e.execute();
        open = false;
    }

    function place(path) {
        Quickshell.execDetached(["xdg-open", path]);
        open = false;
    }

    // launch counts, for the frequent list
    FileView {
        id: usage
        path: Theme.cacheDir + "/launches.json"
        printErrors: false
        onLoaded: { try { sm.counts = JSON.parse(text()); } catch (e) {} }
    }

    PanelWindow {
        id: win
        visible: sm.open || menu.opacity > 0
        screen: Theme.screenFor(sm.output)
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        // leave the taskbar clickable
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.namespace: "aero-startmenu"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: sm.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: sm.open = false }

        Item {
            id: menu
            x: 0
            y: parent.height - height
            width: 404; height: 540
            opacity: sm.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            transform: Translate { y: sm.open ? 0 : 8; Behavior on y { NumberAnimation { duration: 120 } } }

            MouseArea { anchors.fill: parent }

            // glass
            Rectangle {
                anchors.fill: parent
                radius: 6
                border.color: Qt.rgba(0, 0, 0, 0.6)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.36, 0.50, 0.66, 0.86) }
                    GradientStop { position: 1; color: Qt.rgba(0.10, 0.18, 0.28, 0.90) }
                }
                Rectangle {
                    anchors { fill: parent; margins: 1 }
                    radius: 5
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                }
            }

            // left side
            Rectangle {
                id: white
                x: 8; y: 8
                width: 250; height: parent.height - 16 - searchBox.height - 12
                radius: 3
                color: "#ffffff"
                border.color: Qt.rgba(0.2, 0.3, 0.4, 0.8)

                Text {
                    id: listTitle
                    visible: sm.query !== ""
                    x: 10; y: 6
                    text: "Programs (" + sm.list.length + ")"
                    color: "#1e3287"
                    font { family: Aero.font; pixelSize: 12; bold: true }
                }
                Rectangle {
                    visible: listTitle.visible
                    anchors { left: listTitle.right; leftMargin: 6; right: parent.right; rightMargin: 8; verticalCenter: listTitle.verticalCenter }
                    height: 1
                    color: "#d5dfe5"
                }

                ListView {
                    id: listView
                    anchors {
                        top: parent.top; topMargin: listTitle.visible ? 26 : 6
                        left: parent.left; right: parent.right; margins: 4
                        bottom: allRow.top; bottomMargin: 4
                    }
                    clip: true
                    model: sm.list
                    currentIndex: sm.sel
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    readonly property bool small: sm.all || sm.query !== ""
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: listView.width
                        height: listView.small ? 26 : 40
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            visible: row.index === sm.sel || rowMouse.containsMouse
                            border.color: "#7da2ce"
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#eaf3fc" }
                                GradientStop { position: 1; color: "#c5dcf5" }
                            }
                        }
                        IconImage {
                            id: rowIcon
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                            implicitSize: listView.small ? 16 : 32
                            source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        }
                        Text {
                            anchors { left: rowIcon.right; leftMargin: 8; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: row.modelData.name
                            color: "#1b1b1b"
                            font { family: Aero.font; pixelSize: 13 }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: sm.sel = row.index
                            onClicked: sm.launch(row.modelData)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: sm.list.length === 0
                        width: parent.width - 20
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: sm.query !== "" ? "No items match your search." : "Programs you open often show up here."
                        color: "#6d6d6d"
                        font { family: Aero.font; pixelSize: 12 }
                    }
                }

                // All Programs / Back
                Item {
                    id: allRow
                    visible: sm.query === ""
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
                    height: visible ? 30 : 0
                    Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 } height: 1; color: "#d5dfe5" }
                    Rectangle {
                        anchors { fill: parent; topMargin: 3 }
                        radius: 3
                        visible: allMouse.containsMouse
                        border.color: "#7da2ce"
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#eaf3fc" }
                            GradientStop { position: 1; color: "#c5dcf5" }
                        }
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 }
                        text: sm.all ? "◂  Back" : "▸  All Programs"
                        color: "#1b1b1b"
                        font { family: Aero.font; pixelSize: 13 }
                    }
                    MouseArea {
                        id: allMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { sm.all = !sm.all; sm.sel = 0; }
                    }
                }
            }

            // search
            Rectangle {
                id: searchBox
                x: 14
                anchors { bottom: parent.bottom; bottomMargin: 10 }
                width: 238; height: 26
                radius: 2
                color: "#ffffff"
                border.color: search.activeFocus ? "#3d7bad" : "#8e9aa6"
                TextInput {
                    id: search
                    anchors { left: parent.left; leftMargin: 7; right: mag.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    color: "#1b1b1b"
                    selectionColor: "#3399ff"
                    font { family: Aero.font; pixelSize: 13 }
                    clip: true
                    focus: true
                    text: sm.query
                    onTextChanged: { sm.query = text; sm.sel = 0; }
                    Text {
                        anchors.fill: parent
                        visible: search.text === ""
                        text: "Search programs and files"
                        color: "#8c8c8c"
                        font { family: Aero.font; pixelSize: 13; italic: true }
                    }
                    Keys.onPressed: (ev) => {
                        const n = sm.list.length;
                        if (ev.key === Qt.Key_Escape) sm.open = false;
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                            if (sm.query.startsWith(">")) { Quickshell.execDetached(["sh", "-c", sm.query.slice(1)]); sm.open = false; }
                            else sm.launch(sm.list[sm.sel]);
                        }
                        else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab) sm.sel = Math.min(sm.sel + 1, n - 1);
                        else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) sm.sel = Math.max(sm.sel - 1, 0);
                        else return;
                        ev.accepted = true;
                        listView.positionViewAtIndex(sm.sel, ListView.Contain);
                    }
                    Connections {
                        target: sm
                        function onOpenChanged() { if (sm.open) search.forceActiveFocus(); }
                    }
                }
                Text {
                    id: mag
                    anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    color: "#5b6b7a"
                    font { family: Theme.icons; pixelSize: 15 }
                }
            }

            // right side
            Rectangle {
                id: pic
                x: 266 + (130 - width) / 2; y: -26
                width: 64; height: 64
                radius: 5
                border.color: Qt.rgba(0, 0, 0, 0.5)
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f4f8fc" }
                    GradientStop { position: 1; color: "#b7c8da" }
                }
                Rectangle {
                    anchors { fill: parent; margins: 5 }
                    radius: 2
                    color: "#9fb3c8"
                    clip: true
                    // user picture
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: "file:///var/lib/AccountsService/icons/" + sm.user
                        mipmap: true
                    }
                }
            }

            Column {
                x: 264; y: 50
                width: 132
                spacing: 1

                Place { label: sm.user; bold: true; onActivated: sm.place(Theme.home) }
                Place { label: "Documents"; onActivated: sm.place(Theme.home + "/Documents") }
                Place { label: "Pictures"; onActivated: sm.place(Theme.home + "/Pictures") }
                Place { label: "Music"; onActivated: sm.place(Theme.home + "/Music") }
                Place { label: "Downloads"; onActivated: sm.place(Theme.home + "/Downloads") }
                Rectangle { width: parent.width - 16; x: 8; height: 1; color: Qt.rgba(1, 1, 1, 0.2) }
                Place { label: "Computer"; onActivated: sm.place("/") }
                Place { label: "Help and Support"; onActivated: { sm.open = false; Quickshell.execDetached(["foot", "-e", "man", "aro"]); } }
                Place { label: "Run..."; onActivated: { search.text = ">"; search.forceActiveFocus(); } }
            }

            // shut down button
            Rectangle {
                id: shut
                x: 266 + (130 - width) / 2
                anchors { bottom: parent.bottom; bottomMargin: 10 }
                width: 112; height: 26
                radius: 3
                border.color: Qt.rgba(0, 0, 0, 0.6)
                gradient: Gradient {
                    GradientStop { position: 0; color: shutMouse.containsMouse ? "#f6a08a" : "#d9e4ef" }
                    GradientStop { position: 0.5; color: shutMouse.containsMouse ? "#e0553a" : "#9fb3c8" }
                    GradientStop { position: 0.51; color: shutMouse.containsMouse ? "#c8361c" : "#7f97b0" }
                    GradientStop { position: 1; color: shutMouse.containsMouse ? "#e06a3e" : "#a4b9cd" }
                }
                Text {
                    anchors.centerIn: parent
                    text: "Shut down  ▸"
                    color: "white"
                    style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                    font { family: Aero.font; pixelSize: 13 }
                }
                MouseArea {
                    id: shutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { sm.open = false; sm.power?.toggle(sm.output); }
                }
            }
        }
    }
}
