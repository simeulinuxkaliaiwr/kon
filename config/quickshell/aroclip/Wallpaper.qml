import Quickshell
import Quickshell.Wayland
import QtQuick

// wallpaper for hyprland and niri
Variants {
    model: Theme.wm !== "aro" ? Quickshell.screens : []

    PanelWindow {
        required property var modelData
        screen: modelData
        visible: Theme.wallpaper !== ""
        color: Theme.background
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "kon-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Image {
            anchors.fill: parent
            source: Theme.wallpaper !== "" ? "file://" + Theme.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
}
