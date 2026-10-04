import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Particles

// falling snow behind the gadgets and windows
Scope {
    id: snow
    property bool enabled: true

    function toggle() { enabled = !enabled; }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: Aero.on
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}                     // clicks go straight through
            WlrLayershell.namespace: "aero-snow"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // hide instead of unmapping, or it ends up above the gadgets
            Item {
                anchors.fill: parent
                visible: snow.enabled

                ParticleSystem {
                    id: sys
                    anchors.fill: parent
                    running: win.visible && snow.enabled
                }

                // spawn just above the screen
                Emitter {
                    system: sys
                    x: -40; y: -16
                    width: win.width + 80; height: 1
                    emitRate: win.width / 36
                    lifeSpan: 1000 * (win.height + 40) / 32
                    size: 6
                    sizeVariation: 5
                    velocity: AngleDirection { angle: 90; angleVariation: 10; magnitude: 62; magnitudeVariation: 30 }
                }

                // sideways drift
                Wander {
                    system: sys
                    anchors.fill: parent
                    xVariance: 36
                    pace: 24
                }

                ImageParticle {
                    system: sys
                    anchors.fill: parent
                    source: "qrc:///particleresources/glowdot.png"
                    color: "#ffffff"
                    alpha: 0.85
                    alphaVariation: 0.35
                }
            }
        }
    }
}
