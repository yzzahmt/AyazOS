import QtQuick
import AyazOS.UI
import "../components"

Page {
    id: pg
    title: "Ağ ve İnternet"
    subtitle: "Wi-Fi ve kablolu bağlantılar."

    property bool unavailable: false
    property bool wifiOn: true
    property bool scanning: false
    property var networks: []
    property var saved: []
    property var eth: []
    property string busySsid: ""

    function loadAll() {
        Sh.run(["nmcli", "radio", "wifi"], (c, out) => {
            if (c !== 0) { unavailable = true; return; }
            unavailable = false;
            wifiOn = out.trim() === "enabled";
            if (wifiOn) loadWifi();
        });
        Sh.run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"], (c, out) => {
            if (c !== 0) return;
            eth = out.split("\n").filter(l => l).map(l => Sh.splitEsc(l)).filter(p => p[1] === "ethernet")
                .map(p => ({ dev: p[0], state: p[2], conn: p[3] }));
        });
        Sh.run(["nmcli", "-t", "-f", "NAME", "con", "show"], (c, out) => { saved = out.split("\n").filter(l => l); });
    }
    function loadWifi() {
        Sh.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi"], (c, out) => {
            scanning = false;
            if (c !== 0) return;
            const seen = {}, list = [];
            out.split("\n").filter(l => l).forEach(l => {
                const p = Sh.splitEsc(l);
                if (!p[1] || seen[p[1]]) return;
                seen[p[1]] = true;
                list.push({ use: p[0] === "*", ssid: p[1], signal: parseInt(p[2]) || 0, sec: p[3] && p[3] !== "--" ? p[3] : "" });
            });
            list.sort((a, b) => (b.use - a.use) || (b.signal - a.signal));
            networks = list;
        });
    }
    function rescan() { scanning = true; Sh.run(["nmcli", "dev", "wifi", "rescan"], () => loadWifi()); }
    function connect(n) {
        if (n.use) { Sh.run(["nmcli", "con", "down", "id", n.ssid], () => loadAll()); return; }
        const done = (c, out, err) => {
            busySsid = "";
            Sh.toast(c === 0 ? n.ssid + " bağlandı" : "Bağlanılamadı");
            loadAll();
        };
        busySsid = n.ssid;
        if (n.sec && saved.indexOf(n.ssid) < 0) {
            busySsid = "";
            Sh.ask({ title: n.ssid, message: "Bu ağın parolasını gir.", fields: [{ placeholder: "Parola", password: true }], ok: "Bağlan" }, v => {
                busySsid = n.ssid;
                Sh.run(["nmcli", "dev", "wifi", "connect", n.ssid, "password", v[0]], done);
            });
        } else if (saved.indexOf(n.ssid) >= 0) Sh.run(["nmcli", "con", "up", "id", n.ssid], done);
        else Sh.run(["nmcli", "dev", "wifi", "connect", n.ssid], done);
    }
    Component.onCompleted: loadAll()
    Timer { interval: 10000; running: true; repeat: true; onTriggered: pg.loadAll() }

    Text {
        visible: pg.unavailable
        text: "Kullanılamıyor — NetworkManager çalışmıyor."
        color: Theme.textDim
        font { family: Theme.font; pixelSize: 14 }
    }

    Card {
        visible: !pg.unavailable
        heading: "Wi-Fi"
        SRow {
            label: "Wi-Fi"
            sub: pg.wifiOn ? "Açık" : "Kapalı"
            icon: pg.wifiOn ? "wifi" : "wifi-off"
            Toggle {
                checked: pg.wifiOn
                onToggled: v => { pg.wifiOn = v; Sh.run(["nmcli", "radio", "wifi", v ? "on" : "off"], () => { if (v) pg.rescan(); else pg.networks = []; }); }
            }
        }
        SRow {
            visible: pg.wifiOn
            label: "Kullanılabilir ağlar"
            sub: pg.scanning ? "Taranıyor…" : pg.networks.length + " ağ bulundu"
            PillButton { text: "Yeniden tara"; busy: pg.scanning; onClicked: pg.rescan() }
        }
        Repeater {
            model: pg.wifiOn ? pg.networks : []
            SRow {
                required property var modelData
                label: modelData.ssid
                sub: modelData.use ? "Bağlı" : (pg.busySsid === modelData.ssid ? "Bağlanılıyor…" : (modelData.sec ? "Korumalı · %" + modelData.signal : "Açık ağ · %" + modelData.signal))
                icon: "wifi"
                clickable: true
                highlight: modelData.use
                onClicked: pg.connect(modelData)
                Row {
                    spacing: 12
                    Icon { visible: modelData.sec !== ""; name: "lock"; size: 15; color: Theme.textFaint; anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        spacing: 3; anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 4; height: 6 + index * 4; radius: 2
                                anchors.bottom: parent.bottom
                                color: modelData.signal >= (index + 1) * 25 - 12 ? (modelData.use ? Sh.accent : Theme.text) : Qt.rgba(1, 1, 1, 0.16)
                            }
                        }
                    }
                }
            }
        }
    }

    Card {
        visible: !pg.unavailable
        heading: "Kablolu"
        SRow { visible: pg.eth.length === 0; label: "Ethernet"; sub: "Kablolu bağlantı bulunamadı"; icon: "globe" }
        Repeater {
            model: pg.eth
            SRow {
                required property var modelData
                label: "Ethernet · " + modelData.dev
                sub: modelData.state.indexOf("connected") === 0 && modelData.state !== "connecting" ? "Bağlı" + (modelData.conn ? " · " + modelData.conn : "") : "Bağlı değil"
                icon: "globe"
            }
        }
    }
}
