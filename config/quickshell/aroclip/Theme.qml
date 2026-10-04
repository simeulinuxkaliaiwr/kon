pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// colours and motion, from ~/.cache/aroclip/theme.json
Singleton {
    id: theme

    property color background: "#eef3f8"
    property color frame: "#dbe6f1"
    property color frameFocus: "#c3d7ec"
    property color border: "#8ea6c0"
    property color accent: "#3a8ee6"
    property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.3)
    property color text: "#1b2633"
    property color dim: "#5f6f80"
    property color urgent: "#d9342b"
    property color accentInk: "#ffffff"
    property string tagline: "it's 2010 and the snow is falling"
    property string wallpaper: ""
    property string layout: "aero"

    property int radius: 6
    property int borderWidth: 2
    property int gaps: 8
    property int outerGap: 8
    property int barHeight: 30
    property real glass: 0.9   // bar and card opacity
    property real speed: 1              // > 1 is faster
    property real bounce: 1   // 0 is no overshoot
    readonly property real slow: 1 / Math.max(0.1, speed)

    Behavior on accent { ColorAnimation { duration: 600 } }
    Behavior on frame { ColorAnimation { duration: 600 } }
    Behavior on frameFocus { ColorAnimation { duration: 600 } }
    Behavior on border { ColorAnimation { duration: 600 } }
    Behavior on text { ColorAnimation { duration: 600 } }
    Behavior on dim { ColorAnimation { duration: 600 } }
    Behavior on urgent { ColorAnimation { duration: 600 } }

    readonly property string font: "Sans"
    readonly property string icons: "Symbols Nerd Font"
    readonly property int animMs: 340 * slow
    readonly property int focusMs: 160 * slow

    readonly property string home: Quickshell.env("HOME")
    readonly property string bin: home + "/.local/bin/"   // kon's scripts, whatever PATH is
    readonly property string wm: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland"
        : Quickshell.env("NIRI_SOCKET") ? "niri" : "aro"
    readonly property string cacheDir: home + "/.cache/aroclip"

    function screenFor(name) {
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    FileView {
        path: theme.cacheDir + "/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let p;
            try { p = JSON.parse(text()); } catch (e) { return; }
            theme.background = "#" + p.background;
            theme.frame = "#" + p.frame;
            theme.frameFocus = "#" + p.frame_focus;
            theme.border = "#" + p.border;
            theme.accent = "#" + p.accent;
            theme.text = "#" + p.text;
            theme.dim = "#" + p.dim;
            theme.urgent = "#" + p.urgent;
            theme.accentInk = "#" + p.on_accent;
            theme.tagline = p.tagline;
            theme.wallpaper = p.wallpaper ?? "";
            theme.layout = p.layout ?? "aero";
            if (p.radius !== undefined) theme.radius = p.radius;
            if (p.border_width !== undefined) theme.borderWidth = p.border_width;
            if (p.gaps !== undefined) theme.gaps = p.gaps;
            if (p.outer_gaps !== undefined) theme.outerGap = p.outer_gaps;
            if (p.bar_height !== undefined) theme.barHeight = p.bar_height;
            if (p.opacity !== undefined) theme.glass = p.opacity;
            if (p.speed !== undefined) theme.speed = p.speed;
            if (p.bounce !== undefined) theme.bounce = p.bounce;
        }
    }
}
