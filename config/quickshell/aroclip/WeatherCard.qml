import Quickshell
import Quickshell.Io
import QtQuick

// win7 weather gadget, data from open-meteo
Item {
    id: root
    implicitWidth: 292
    implicitHeight: 200

    property var now: null              // { temp, code, day }
    property var days: []               // [{ date, code, max, min }]

    function words(code) {
        if (code === 0) return "Clear";
        if (code === 1) return "Mostly Clear";
        if (code === 2) return "Partly Cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 57) return "Drizzle";
        if (code >= 61 && code <= 67) return "Rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code >= 80 && code <= 82) return "Showers";
        if (code === 85 || code === 86) return "Snow Showers";
        if (code >= 95) return "Thunderstorms";
        return "";
    }

    // sky colours for the weather and time
    function sky(code, day) {
        const storm = code >= 95;
        const snow = (code >= 71 && code <= 77) || code === 85 || code === 86;
        const wet = (code >= 51 && code <= 67) || (code >= 80 && code <= 82);
        const grey = code === 3 || code === 45 || code === 48;
        if (!day) return storm || wet || grey ? ["#141b27", "#34404f"] : ["#081633", "#284878"];
        if (storm) return ["#262c38", "#59606f"];
        if (snow) return ["#7d98b8", "#d6e2ef"];
        if (wet) return ["#46566a", "#8594a5"];
        if (grey) return ["#5f7084", "#a6b3c1"];
        if (code === 2) return ["#3f7fc2", "#9cc6ea"];
        return ["#1f6fd0", "#86c4f4"];
    }
    readonly property var skyNow: root.now ? sky(root.now.code, root.now.day) : ["#3f6f9f", "#8fb4d6"]

    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "15",
            "https://api.open-meteo.com/v1/forecast?latitude=" + Aero.lat + "&longitude=" + Aero.lon
            + "&current=temperature_2m,weather_code,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j;
                try { j = JSON.parse(this.text); } catch (e) { return; }
                root.now = { temp: j.current.temperature_2m, code: j.current.weather_code, day: j.current.is_day === 1 };
                const d = j.daily;
                root.days = d.time.map((t, i) => ({
                    date: new Date(t + "T12:00:00"), code: d.weather_code[i],
                    max: d.temperature_2m_max[i], min: d.temperature_2m_min[i]
                }));
            }
        }
    }
    Timer { interval: 1800000; repeat: true; running: Aero.on && Aero.located; triggeredOnStart: true; onTriggered: fetch.running = true }

    // shadow and sky
    Rectangle {
        x: 2; y: 4; width: parent.width - 2; height: parent.height - 4; radius: 14
        color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        id: card
        width: parent.width - 3; height: parent.height - 5; radius: 14
        border.color: Qt.rgba(0, 0, 0, 0.5)
        gradient: Gradient {
            GradientStop { position: 0; color: root.skyNow[0] }
            GradientStop { position: 1; color: root.skyNow[1] }
        }
        // inner edge
        Rectangle {
            anchors { fill: parent; margins: 1 }
            radius: 13
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.45)
        }
        // gloss
        Rectangle {
            x: 1; y: 1; width: parent.width - 2; height: parent.height * 0.46; radius: 13
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.34) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            }
        }
        // forecast strip
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: 66
            radius: 13
            color: Qt.rgba(0, 0, 0, 0.18)
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.25) }
        }
    }

    WeatherArt {
        x: 6; y: 2
        width: 132; height: 110
        code: root.now ? root.now.code : 3
        day: root.now ? root.now.day : true
    }

    Column {
        anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 6 }
        Text {
            anchors.right: parent.right
            text: root.now ? Math.round(root.now.temp) + "°" : "--°"
            color: "white"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
            font { family: Aero.font; pixelSize: 44; weight: Font.Light }
        }
        Text {
            anchors.right: parent.right
            text: root.now ? root.words(root.now.code) : "loading…"
            color: "white"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
            font { family: Aero.font; pixelSize: 13; bold: true }
        }
        Text {
            anchors.right: parent.right
            text: root.days.length ? "H " + Math.round(root.days[0].max) + "°   L " + Math.round(root.days[0].min) + "°" : ""
            color: Qt.rgba(1, 1, 1, 0.85)
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
            font { family: Aero.font; pixelSize: 12 }
        }
        Item { width: 1; height: 4 }
        Text {
            anchors.right: parent.right
            text: Aero.city
            color: "white"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
            font { family: Aero.font; pixelSize: 13 }
        }
    }

    // next three days
    Row {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6; bottomMargin: 18 }
        Repeater {
            model: root.days.slice(1, 4)
            Item {
                required property var modelData
                required property int index
                width: (parent.width) / 3; height: 44
                Rectangle {
                    visible: index > 0
                    y: 2; width: 1; height: parent.height - 4
                    color: Qt.rgba(1, 1, 1, 0.22)
                }
                Text {
                    x: 8; y: -1
                    text: modelData.date.toLocaleDateString(Qt.locale(), "ddd")
                    color: "white"
                    style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
                    font { family: Aero.font; pixelSize: 11; bold: true }
                }
                Column {
                    x: 8; y: 15
                    Text { text: Math.round(modelData.max) + "°"; color: "white"; font { family: Aero.font; pixelSize: 13 } }
                    Text { text: Math.round(modelData.min) + "°"; color: Qt.rgba(1, 1, 1, 0.7); font { family: Aero.font; pixelSize: 11 } }
                }
                WeatherArt {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    width: 46; height: 38
                    code: modelData.code
                    day: true
                }
            }
        }
    }

    Text {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 5 }
        text: "Open-Meteo"
        color: Qt.rgba(1, 1, 1, 0.6)
        font { family: Aero.font; pixelSize: 9 }
    }
}
