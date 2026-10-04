//@ pragma IconTheme Papirus-Dark
// aero shell, driven by ~/.local/bin/aroclip

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    // hot reload crashes quickshell 0.3.1
    settings.watchFiles: false

    Clipboard { id: clipboard }
    Emoji { id: emoji }
    Power { id: power }
    Osd { id: osd }
    Toasts { id: toasts }
    Wallpaper {}
    Snow { id: snow }   // before Desktop so it stays under it
    Flip3D { id: flip3d }
    StartMenu { id: startMenu; power: power }
    Taskbar { launcher: startMenu }
    Desktop {}
    Recorder {
        id: recorder
        onFinished: (file, output, ok) => toasts.show(ok
            ? { output: output, icon: "󰕧", title: "recording saved", detail: file.split("/").pop() }
            : { output: output, icon: "󰅚", title: "recording failed", detail: "see qs log" })
    }

    IpcHandler {
        target: "clip"
        function toggle(output: string): void { clipboard.toggle(output); }
        function shot(file: string, output: string): void {
            toasts.show({ output: output, image: file, flash: true, icon: "󰄀", title: "copied to clipboard" });
        }
    }

    IpcHandler {
        target: "flip"
        function toggle(): void { flip3d.toggle(); }
        function close(): void { flip3d.close(); }
    }

    IpcHandler {
        target: "snow"
        function toggle(): void { snow.toggle(); }
    }

    IpcHandler {
        target: "apps"
        function toggle(output: string): void { startMenu.toggle(output); }
    }

    IpcHandler {
        target: "emoji"
        function toggle(output: string): void { emoji.toggle(output); }
    }

    IpcHandler {
        target: "power"
        function toggle(output: string): void { power.toggle(output); }
    }

    IpcHandler {
        target: "osd"
        function display(kind: string, value: real, muted: bool, output: string): void { osd.show(kind, value, muted, output); }
    }

    IpcHandler {
        target: "color"
        function display(hex: string, output: string): void {
            const c = Qt.color(hex);
            const rgb = [c.r, c.g, c.b].map(v => Math.round(v * 255)).join(", ");
            toasts.show({ output: output, swatch: hex, icon: "󰈊", title: hex, detail: "rgb " + rgb });
        }
    }

    // kon finished applying
    IpcHandler {
        target: "kon"
        function changed(id: string, name: string, tagline: string): void {
            toasts.show({ icon: "󰋄", title: name, detail: tagline });
        }
    }

    IpcHandler {
        target: "rec"
        function toggle(output: string, geometry: string): void { recorder.toggle(output, geometry); }
        function active(): bool { return recorder.active; }
    }
}
