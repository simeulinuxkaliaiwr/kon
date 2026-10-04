import Quickshell
import Quickshell.Wayland
import QtQuick

// toasts in the bottom right
Scope {
    id: toasts

    property var current: null

    // opts: { output, image, swatch, icon, title, detail, flash, lift }
    function show(opts) {
        if (current) current.leave();
        current = toast.createObject(toasts, { opts: opts });
    }

    Component {
        id: toast

        Scope {
            id: t
            property var opts
            readonly property var scr: Theme.screenFor(opts.output ?? "")
            readonly property bool hasImage: !!opts.image
            readonly property bool hasSwatch: !!opts.swatch

            function leave() { stay.stop(); out.start(); }

            PanelWindow {
                id: flash
                visible: !!t.opts.flash
                screen: t.scr
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "aroclip-flash"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                mask: Region {}

                Rectangle {
                    anchors.fill: parent
                    color: Theme.text
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: flash.visible
                        NumberAnimation { to: 0.28; duration: 60 * Theme.slow; easing.type: Easing.OutQuad }
                        NumberAnimation { to: 0; duration: 320 * Theme.slow; easing.type: Easing.OutCubic }
                        ScriptAction { script: flash.visible = false }
                    }
                }
            }

            PanelWindow {
                id: pop
                screen: t.scr
                color: "transparent"
                anchors { bottom: true; right: true }
                margins.bottom: t.opts.lift ?? 0
                implicitWidth: 300
                implicitHeight: box.height + 36
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "aroclip-toast"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                Item {
                    id: box
                    width: 270
                    height: (t.hasImage ? 148 : t.hasSwatch ? 92 : 0) + 44
                    y: 18
                    x: pop.width
                    opacity: 0

                    SequentialAnimation {
                        running: true
                        ParallelAnimation {
                            NumberAnimation { target: box; property: "x"; to: pop.width - box.width - 18; duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.1 * Theme.bounce }
                            NumberAnimation { target: box; property: "opacity"; to: 1; duration: 200 * Theme.slow }
                        }
                        ScriptAction { script: stay.start() }
                    }
                    Timer { id: stay; interval: 2600; onTriggered: out.start() }
                    SequentialAnimation {
                        id: out
                        ParallelAnimation {
                            NumberAnimation { target: box; property: "x"; to: pop.width; duration: 260 * Theme.slow; easing.type: Easing.InCubic }
                            NumberAnimation { target: box; property: "opacity"; to: 0; duration: 260 * Theme.slow }
                        }
                        ScriptAction {
                            script: {
                                if (toasts.current === t) toasts.current = null;
                                t.destroy();
                            }
                        }
                    }

                    MouseArea { anchors.fill: parent; onClicked: t.leave() }

                    Rectangle {
                        anchors.fill: parent
                        radius: Aero.on ? 3 : Theme.radius
                        color: Theme.frameFocus
                        gradient: Aero.on ? Aero.flyout : null
                        border.width: Aero.on ? 1 : Theme.borderWidth
                        border.color: Aero.on ? Aero.flyoutEdge : Theme.accent
                    }

                    Image {
                        visible: t.hasImage
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                        height: 132
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize: Qt.size(508, 264)
                        source: t.hasImage ? "file://" + t.opts.image : ""
                    }

                    Rectangle {
                        id: swatch
                        visible: t.hasSwatch
                        anchors { top: parent.top; left: parent.left; margins: 8 }
                        height: 76
                        width: 0
                        radius: 3
                        color: t.opts.swatch ?? "transparent"
                        border.width: 1
                        border.color: Theme.border
                        NumberAnimation on width {
                            running: t.hasSwatch
                            to: box.width - 16; duration: Theme.animMs * 1.3; easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: icon
                        visible: text !== ""
                        anchors { bottom: parent.bottom; bottomMargin: 12; left: parent.left; leftMargin: 12 }
                        text: t.opts.icon ?? ""
                        color: Theme.accent
                        font { family: Theme.icons; pixelSize: 14 }
                    }
                    Text {
                        anchors { bottom: parent.bottom; bottomMargin: 12; left: icon.visible ? icon.right : parent.left; leftMargin: icon.visible ? 8 : 12 }
                        text: t.opts.title ?? ""
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 12; bold: true }
                    }
                    Text {
                        anchors { bottom: parent.bottom; bottomMargin: 12; right: parent.right; rightMargin: 12 }
                        width: 120
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: t.opts.detail ?? ""
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
