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

    // --- Oturum ---
    function lock() { Quickshell.execDetached(["qs", "-c", "ayazos", "ipc", "call", "lock", "lock"]); }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]); }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function logout() { Quickshell.execDetached(["wayland-logout"]); }
}
