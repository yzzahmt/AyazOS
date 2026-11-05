import QtQuick
import AyazOS.UI
import "../components"

Page {
    id: pg
    title: "Güncellemeler"
    subtitle: "Sistemini ve uygulamalarını güncel tut."

    property int count: -1          // -1: bilinmiyor
    property bool checking: false
    property bool unavailable: false
    property bool applying: false
    property string progress: ""
    property var pkgs: []

    function check() {
        checking = true;
        Sh.run(["ayaz-update", "check"], (c, out) => {
            checking = false;
            if (c === 127) { unavailable = true; count = -1; return; }
            unavailable = false;
            count = parseInt(out.trim().split("\n").pop()) || 0;
            if (count > 0) Sh.run(["ayaz-update", "list"], (c2, o2) => {
                pkgs = o2.split("\n").filter(l => l.indexOf("/") > 0).map(l => {
                    const m = l.match(/^([^\/]+)\/\S+\s+(\S+)/);
                    return m ? { name: m[1], ver: m[2] } : { name: l, ver: "" };
                });
            }); else pkgs = [];
        });
    }
    function apply() {
        applying = true; progress = "Başlatılıyor…";
        Sh.stream("exec ayaz-update apply 2>&1", l => { progress = l.slice(0, 90); }, (c) => {
            applying = false;
            progress = "";
            Sh.toast(c === 0 ? "Güncellemeler kuruldu" : "Güncelleme tamamlanamadı");
            check();
        });
    }
    Component.onCompleted: check()

    Card {
        Item {
            width: parent.width; height: 120
            Rectangle {
                id: badge
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 64; radius: 20
                color: Qt.rgba(Sh.accent.r, Sh.accent.g, Sh.accent.b, 0.16)
                border.width: 1; border.color: Qt.rgba(Sh.accent.r, Sh.accent.g, Sh.accent.b, 0.4)
                Icon {
                    id: spin
                    anchors.centerIn: parent
                    name: pg.count === 0 ? "check" : "refresh-cw"; size: 28; color: Sh.accent
                    RotationAnimator on rotation { running: pg.checking || pg.applying; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
                }
            }
            Column {
                anchors { left: badge.right; leftMargin: 20; right: btns.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 5
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: pg.unavailable ? "Kullanılamıyor" : pg.applying ? "Güncelleniyor…" : pg.checking ? "Denetleniyor…" : pg.count === 0 ? "Sistemin güncel" : pg.count > 0 ? pg.count + " güncelleme var" : "Henüz denetlenmedi"
                    color: Theme.text; font { family: Theme.font; pixelSize: 20; weight: Font.Medium }
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: pg.unavailable ? "Güncelleme hizmeti (ayaz-update) bu sistemde yok." : pg.applying ? pg.progress : "AyazOS " + "0.1.0"
                    color: Theme.textDim; font { family: Theme.font; pixelSize: 13 }
                }
            }
            Row {
                id: btns
                anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                spacing: 10
                PillButton { text: "Denetle"; busy: pg.checking; enabled2: !pg.applying; onClicked: pg.check() }
                PillButton { visible: pg.count > 0; text: "Şimdi güncelle"; kind: "primary"; busy: pg.applying; onClicked: pg.apply() }
            }
        }
    }

    Card {
        visible: pg.pkgs.length > 0
        heading: "Güncellenecek paketler"
        Repeater {
            model: pg.pkgs.slice(0, 40)
            SRow {
                required property var modelData
                label: modelData.name
                icon: "package"
                Text { text: modelData.ver; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
            }
        }
    }

    Card {
        heading: "Seçenekler"
        footnote: "Otomatik güncellemeler etkinse güvenlik yamaları arka planda indirilir."
        SRow {
            label: "Otomatik güncellemeler"
            sub: "Güncellemeleri arka planda indir"
            icon: "cloud-download"
            Toggle { checked: Sh.get("autoUpdates", true); onToggled: v => Sh.set("autoUpdates", v) }
        }
    }
}
