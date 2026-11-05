import QtQuick
import AyazOS.UI
import "../components"

Page {
    id: pg
    title: "Güç ve Pil"
    subtitle: "Performans, pil sağlığı ve uyku ayarları."

    property string profile: ""
    property bool profilesOk: true
    property var bat: null
    property bool batLoaded: false
    readonly property var profiles: [{ label: "Güç tasarrufu", value: "power-saver" }, { label: "Dengeli", value: "balanced" }, { label: "Performans", value: "performance" }]

    function load() {
        Sh.run(["powerprofilesctl", "get"], (c, out) => { profilesOk = c === 0; profile = out.trim(); });
        Sh.sh("b=$(upower -e 2>/dev/null | grep -m1 BAT) && [ -n \"$b\" ] && upower -i \"$b\"", (c, out) => {
            batLoaded = true;
            if (c !== 0 || !out) { bat = null; return; }
            const g = k => { const m = out.match(new RegExp("^\\s*" + k + ":\\s+(.+)$", "m")); return m ? m[1].trim() : ""; };
            const full = parseFloat(g("energy-full")), design = parseFloat(g("energy-full-design"));
            bat = { pct: parseInt(g("percentage")) || 0, state: g("state"), health: design > 0 ? Math.round(full / design * 100) : 0,
                    time: g("time to empty") || g("time to full"), rate: g("energy-rate") };
        });
    }
    Component.onCompleted: load()
    Timer { interval: 15000; running: true; repeat: true; onTriggered: pg.load() }

    readonly property var screenOpts: [{ label: "1 dakika", value: 60 }, { label: "5 dakika", value: 300 }, { label: "10 dakika", value: 600 }, { label: "30 dakika", value: 1800 }, { label: "Hiçbir zaman", value: 0 }]
    readonly property var sleepOpts: [{ label: "15 dakika", value: 900 }, { label: "30 dakika", value: 1800 }, { label: "1 saat", value: 3600 }, { label: "Hiçbir zaman", value: 0 }]

    Card {
        heading: "Pil"
        SRow {
            visible: pg.batLoaded && pg.bat === null
            label: "Pil bulunamadı"
            sub: "Bu cihaz şebeke gücüyle çalışıyor"
            icon: "zap"
        }
        Item {
            visible: pg.bat !== null
            width: parent.width; height: pg.bat ? 96 : 0
            Text {
                id: pct
                x: 24; anchors.verticalCenter: parent.verticalCenter
                text: pg.bat ? pg.bat.pct + "%" : ""
                color: Theme.text
                font { family: Theme.font; pixelSize: 42; weight: Font.Light }
            }
            Column {
                anchors { left: pct.right; leftMargin: 28; right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                spacing: 10
                Rectangle {
                    width: parent.width; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle {
                        width: parent.width * (pg.bat ? pg.bat.pct / 100 : 0); height: parent.height; radius: 4
                        color: pg.bat && pg.bat.pct <= 20 ? Theme.danger : Sh.accent
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    text: pg.bat ? ({ "charging": "Şarj oluyor", "discharging": "Pil kullanılıyor", "fully-charged": "Tam dolu", "pending-charge": "Şarj bekliyor" }[pg.bat.state] || pg.bat.state) : ""
                    color: Theme.textDim
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
        }
        SRow {
            visible: pg.bat !== null && pg.bat.health > 0
            label: "Pil sağlığı"
            sub: "Tasarım kapasitesine göre"
            icon: "battery-medium"
            Text { text: pg.bat ? "%" + pg.bat.health : ""; color: Theme.text; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
        }
    }

    Card {
        heading: "Güç profili"
        SRow {
            label: "Profil"
            sub: pg.profilesOk ? "Performans ve pil ömrü dengesi" : "Kullanılamıyor — güç profili hizmeti yok"
            icon: "gauge"
            visible: true
            Segmented {
                visible: pg.profilesOk
                segWidth: 108
                model: pg.profiles
                currentIndex: Math.max(0, ["power-saver", "balanced", "performance"].indexOf(pg.profile))
                onPicked: (i, v) => { pg.profile = v; Sh.run(["powerprofilesctl", "set", v], c => { if (c !== 0) Sh.toast("Profil değiştirilemedi"); }); }
            }
        }
    }

    Card {
        heading: "Zaman aşımları"
        footnote: "Ekranı kapatma süresi hemen uygulanır; uyku süresi bir sonraki oturumda etkin olur."
        SRow {
            label: "Ekranı kapat"
            sub: "Hareketsiz kalınca"
            icon: "monitor"
            Dropdown {
                model: pg.screenOpts
                current: Sh.get("screenOff", 600)
                onPicked: v => { Sh.set("screenOff", v); Sh.iniSet("idle", "dpms_timeout", v === 0 ? -1 : v); }
            }
        }
        SRow {
            label: "Uyku kipine geç"
            sub: "Hareketsiz kalınca"
            icon: "moon"
            Dropdown {
                model: pg.sleepOpts
                current: Sh.get("sleep", 1800)
                onPicked: v => Sh.set("sleep", v)
            }
        }
    }
}
