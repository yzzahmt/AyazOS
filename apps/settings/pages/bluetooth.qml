import QtQuick
import AyazOS.UI
import "../components"

Page {
    id: pg
    title: "Bluetooth"
    subtitle: "Kulaklık, fare ve diğer aygıtlar."

    property bool unavailable: false
    property bool powered: false
    property bool scanning: false
    property var devices: []
    property string busyMac: ""

    function mapDevs(out) {
        const o = {};
        out.split("\n").forEach(l => { const m = l.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.*)$/); if (m) o[m[1]] = m[2]; });
        return o;
    }
    function load() {
        Sh.run(["bluetoothctl", "show"], (c, out) => {
            if (c !== 0 || out.indexOf("Controller") < 0) { unavailable = true; return; }
            unavailable = false;
            powered = /Powered:\s+yes/.test(out);
            if (!powered) { devices = []; return; }
            Sh.sh("bluetoothctl devices; echo ---P; bluetoothctl devices Paired 2>/dev/null; echo ---C; bluetoothctl devices Connected 2>/dev/null", (c2, o2) => {
                const parts = o2.split(/---P\n?|---C\n?/);
                const all = mapDevs(parts[0] || ""), paired = mapDevs(parts[1] || ""), conn = mapDevs(parts[2] || "");
                devices = Object.keys(all).map(m => ({ mac: m, name: all[m], paired: !!paired[m], connected: !!conn[m] }))
                    .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
            });
        });
    }
    function scan() {
        scanning = true;
        Sh.run(["bluetoothctl", "--timeout", "8", "scan", "on"], () => { scanning = false; load(); });
    }
    function act(d) {
        busyMac = d.mac;
        const fin = (c) => { busyMac = ""; if (c !== 0) Sh.toast("İşlem başarısız"); load(); };
        if (d.connected) Sh.run(["bluetoothctl", "disconnect", d.mac], fin);
        else if (d.paired) Sh.run(["bluetoothctl", "connect", d.mac], fin);
        else Sh.sh("bluetoothctl pair " + d.mac + " && bluetoothctl trust " + d.mac + " && bluetoothctl connect " + d.mac, fin);
    }
    Component.onCompleted: load()
    Timer { interval: 6000; running: true; repeat: true; onTriggered: if (!pg.scanning && pg.busyMac === "") pg.load() }

    Text {
        visible: pg.unavailable
        text: "Kullanılamıyor — Bluetooth denetleyicisi bulunamadı."
        color: Theme.textDim
        font { family: Theme.font; pixelSize: 14 }
    }
    Card {
        visible: !pg.unavailable
        heading: "Bluetooth"
        SRow {
            label: "Bluetooth"
            sub: pg.powered ? "Açık" : "Kapalı"
            icon: "bluetooth"
            Toggle { checked: pg.powered; onToggled: v => { pg.powered = v; Sh.run(["bluetoothctl", "power", v ? "on" : "off"], () => pg.load()); } }
        }
        SRow {
            visible: pg.powered
            label: "Yakındaki aygıtlar"
            sub: pg.scanning ? "Aranıyor…" : "Yeni aygıt eşleştirmek için ara"
            PillButton { text: "Ara"; busy: pg.scanning; onClicked: pg.scan() }
        }
    }
    Card {
        visible: !pg.unavailable && pg.powered
        heading: "Aygıtlar"
        SRow { visible: pg.devices.length === 0; label: "Aygıt yok"; sub: "Aygıtı eşleştirme kipine alıp Ara'ya bas" }
        Repeater {
            model: pg.devices
            SRow {
                required property var modelData
                label: modelData.name
                sub: pg.busyMac === modelData.mac ? "Bekleyin…" : (modelData.connected ? "Bağlı" : (modelData.paired ? "Eşleşmiş" : "Eşleşmemiş")) + " · " + modelData.mac
                icon: "bluetooth"
                highlight: modelData.connected
                PillButton {
                    text: modelData.connected ? "Bağlantıyı kes" : (modelData.paired ? "Bağlan" : "Eşleştir")
                    kind: modelData.connected ? "secondary" : "primary"
                    busy: pg.busyMac === modelData.mac
                    onClicked: pg.act(modelData)
                }
            }
        }
    }
}
