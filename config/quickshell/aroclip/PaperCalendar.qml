import Quickshell
import QtQuick

// tear-off calendar gadget
Item {
    id: root
    implicitWidth: 156
    implicitHeight: 168

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // shadow
    Rectangle {
        x: 3; y: 12
        width: page.width; height: page.height
        radius: 3
        color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        id: page
        y: 8
        width: parent.width - 4; height: parent.height - 12
        radius: 3
        border.color: "#b8480a"
        gradient: Gradient {
            GradientStop { position: 0; color: "#ff9a3c" }
            GradientStop { position: 1; color: "#ee6410" }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 4
            spacing: -6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.toLocaleDateString(Qt.locale(), "dddd")
                color: "white"
                font { family: Aero.font; pixelSize: 15 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.getDate()
                color: "white"
                font { family: Aero.font; pixelSize: 78; weight: Font.Light }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                color: "white"
                font { family: Aero.font; pixelSize: 14 }
            }
        }
    }

    // rings
    Row {
        anchors.horizontalCenter: page.horizontalCenter
        y: 2
        spacing: 4
        Repeater {
            model: 14
            Rectangle {
                width: 5; height: 14
                radius: 2.5
                color: "transparent"
                border.width: 1.5
                border.color: "#3a3f46"
            }
        }
    }
}
