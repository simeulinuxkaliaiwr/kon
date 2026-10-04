import Quickshell
import Quickshell.Wayland
import QtQuick

// desktop gadgets, first screen only
Scope {
    id: desk

    readonly property var screen: Quickshell.screens[0]
    readonly property int edge: 14
    readonly property bool shown: Aero.on && !Aero.widgetsHidden && settled

    // load after Snow so it stacks above it
    property bool settled: false
    Timer { interval: 300; running: Aero.on && !desk.settled; onTriggered: desk.settled = true }
    Connections { target: Aero; function onOnChanged() { if (!Aero.on) desk.settled = false; } }

    component Gadget: PanelWindow {
        property int fromTop: -1        // from the top edge, or
        property int fromBottom: -1     // from the bottom edge
        property int fromRight: desk.edge
        property bool glass: false   // blur behind it
        default property alias content: holder.data
        screen: desk.screen
        visible: desk.shown
        color: "transparent"
        anchors { top: fromTop >= 0; bottom: fromBottom >= 0; right: true }
        margins { top: Math.max(0, fromTop); bottom: Math.max(0, fromBottom); right: fromRight }
        implicitWidth: holder.childrenRect.width
        implicitHeight: holder.childrenRect.height
        exclusionMode: ExclusionMode.Normal   // stay clear of the taskbar
        exclusiveZone: 0
        WlrLayershell.namespace: glass ? "aero-glass" : "aero-gadget"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Item { id: holder; anchors.fill: parent }
    }

    // top row
    Gadget { fromTop: desk.edge; WeatherCard {} }
    Gadget { fromTop: desk.edge; fromRight: desk.edge + 292 + 16; PaperCalendar {} }
    Gadget { fromTop: desk.edge - 6; fromRight: desk.edge + 292 + 16 + 156 + 14; AeroClock {} }

    // under the weather
    Gadget { fromTop: desk.edge + 200 + 16; fromRight: desk.edge + 4; glass: true; NetCard {} }

    // left of the network panel
    Gadget { fromTop: desk.edge + 200 + 16; fromRight: desk.edge + 4 + 158 + 16; CpuMeter {} }

    // under the network panel, no blur since the corners are round
    Gadget { fromTop: desk.edge + 200 + 16 + 392 + 16; fromRight: desk.edge + 4; ChibiCard {} }

    // bottom right, above the taskbar
    Gadget {
        fromBottom: 6; fromRight: 8
        Item {
            // room for the tilt
            width: logo.width + 6; height: logo.height + 20
            Text {
                id: logo
                y: 16
                text: "K-ON!"
                color: "white"
                style: Text.Outline
                styleColor: "#24324a"
                font { family: "Open Sans"; pixelSize: 58; weight: Font.ExtraBold; italic: true }
                transform: Rotation { angle: -4 }
            }
        }
    }
}
