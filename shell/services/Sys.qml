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
        command: ["curl", "-s", "--max-time", "8", "https://tr.wttr.in/?format=%t|%C|%l|%x"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|");
                if (p.length < 4 || text.indexOf("<") >= 0) return;
                root.weatherTemp = p[0].replace("+", "");
                root.weatherDesc = p[1];
                root.weatherPlace = p[2].split(",")[0];
                const sym = p[3];
                root.weatherIcon = sym.indexOf("!") >= 0 ? "cloud-lightning"
                    : sym.indexOf("*") >= 0 ? "cloud-snow"
                    : (sym.indexOf("/") >= 0 || sym.indexOf(".") >= 0) ? "cloud-rain"
                    : sym.indexOf("=") >= 0 ? "cloud-fog"
                    : sym === "o" ? "sun" : sym === "m" ? "cloud-sun" : "cloud";
            }
        }
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
