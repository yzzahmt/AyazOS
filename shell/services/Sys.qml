pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Sistem durumu: ses, pil, ağ, saat. Yoklama yerine olay tabanlı.
Singleton {
    id: root

    // --- Ses ---
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    function setVolume(v) { if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, v)); }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }
    PwObjectTracker { objects: [root.sink] }

    // --- Pil ---
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

    // --- Ağ (NetworkManager, nmcli monitor ile olay tabanlı) ---
    property string netKind: "none"   // wifi | ethernet | none
    property string netName: ""
    property int netStrength: 0
    property bool wifiEnabled: true

    Process {
        id: netQuery
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kind = "none", name = "";
                for (const line of text.trim().split("\n")) {
                    const [type, state, conn] = line.split(":");
                    if (state === "connected" && (type === "wifi" || type === "ethernet")) {
                        if (kind !== "ethernet") { kind = type; name = conn; }
                    }
                }
                root.netKind = kind;
                root.netName = name;
                if (kind === "wifi") wifiSignal.running = true;
            }
        }
    }
    Process {
        id: wifiSignal
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n"))
                    if (line.startsWith("*:")) root.netStrength = parseInt(line.slice(2)) || 0;
            }
        }
    }
    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: refresh.restart() }
    }
    Timer { id: refresh; interval: 400; onTriggered: netQuery.running = true }
    Component.onCompleted: netQuery.running = true

    // --- Saat ---
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date
    readonly property string time: Qt.formatTime(now, "HH:mm")
    readonly property string dateShort: Qt.locale("tr_TR").toString(now, "d MMM ddd")
    readonly property string dateLong: Qt.locale("tr_TR").toString(now, "d MMMM dddd").toLocaleUpperCase(Qt.locale("tr_TR"))

    // --- Hava durumu (wttr.in, konum IP'den; 30 dakikada bir) ---
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherPlace: ""
    property string weatherIcon: "cloud"
    Process {
        id: weatherQuery
        command: ["curl", "-s", "--max-time", "10", "https://wttr.in/?format=j1&lang=tr"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const c = j.current_condition[0];
                    const code = parseInt(c.weatherCode);
                    root.weatherTemp = c.temp_C + "°C";
                    root.weatherDesc = root.weatherText(code);
                    root.weatherPlace = j.nearest_area?.[0]?.areaName?.[0]?.value ?? "";
                    const thunder = [200, 386, 389, 392, 395], fog = [143, 248, 260];
                    const snow = [179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377];
                    root.weatherIcon = code === 113 ? "sun" : code === 116 ? "cloud-sun" : (code === 119 || code === 122) ? "cloud"
                        : thunder.includes(code) ? "cloud-lightning" : fog.includes(code) ? "cloud-fog"
                        : snow.includes(code) ? "cloud-snow" : "cloud-rain";
                } catch (e) {}
            }
        }
    }
    function weatherText(code) {
        if (code === 113) return "Açık";
        if (code === 116) return "Parçalı bulutlu";
        if (code === 119) return "Bulutlu";
        if (code === 122) return "Kapalı";
        if ([143, 248, 260].includes(code)) return "Sisli";
        if ([200, 386, 389, 392, 395].includes(code)) return "Gök gürültülü";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(code)) return "Karlı";
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(code)) return "Karla karışık yağmur";
        if ([176, 263, 266, 293, 296, 353].includes(code)) return "Hafif yağmurlu";
        return "Yağmurlu";
    }
    Timer { interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherQuery.running = true }

    // --- Güncellemeler (6 saatte bir kontrol) ---
    property int updates: 0
    Process {
        id: updCheck
        command: ["sh", "-c", "command -v ayaz-update >/dev/null && ayaz-update check || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.updates = parseInt(text) || 0 }
    }
    Timer { interval: 6 * 3600 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: updCheck.running = true }

    // --- Oturum ---
    function lock() { Quickshell.execDetached(["qs", "-c", "ayazos", "ipc", "call", "lock", "lock"]); }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]); }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function logout() { Quickshell.execDetached(["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""]); }
}
