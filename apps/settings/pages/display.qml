import QtQuick
import AyazOS.UI
import "../components"

Page {
    id: pg
    title: "Ekran"
    subtitle: "Çözünürlük, yenileme hızı ve gece ışığı."

    property var outputs: []
    property bool unavailable: false
    property bool loaded: false

    function load() {
        Sh.run(["wlr-randr", "--json"], (code, out) => {
            loaded = true;
            if (code !== 0) { unavailable = true; outputs = []; return; }
            try {
                const arr = JSON.parse(out);
                outputs = arr.filter(o => o.enabled !== false).map(o => {
                    const modes = o.modes || [];
                    const cur = modes.find(m => m.current) || modes[0] || { width: 0, height: 0, refresh: 0 };
                    return { name: o.name, title: (o.make ? o.make + " " : "") + (o.model || o.name),
                             modes: modes, curW: cur.width, curH: cur.height, curR: cur.refresh, scale: o.scale || 1 };
                });
                unavailable = outputs.length === 0;
            } catch (e) { unavailable = true; }
        });
    }
    Component.onCompleted: load()

    Text {
        visible: pg.loaded && pg.unavailable
        text: "Kullanılamıyor — ekran bilgisi alınamadı."
        color: Theme.textDim
        font { family: Theme.font; pixelSize: 14 }
    }

    Repeater {
        model: pg.outputs
        Card {
            id: oc
            required property var modelData
            property int selW: modelData.curW
            property int selH: modelData.curH
            property real selR: modelData.curR
            property real selScale: modelData.scale
            property bool applying: false
            readonly property var resList: {
                const seen = {}, out = [];
                modelData.modes.forEach(m => { const k = m.width + "x" + m.height; if (!seen[k]) { seen[k] = 1; out.push({ label: m.width + " × " + m.height, value: k }); } });
                return out;
            }
            readonly property var rateList: {
                const out = [];
                modelData.modes.filter(m => m.width === selW && m.height === selH)
                    .sort((a, b) => b.refresh - a.refresh)
                    .forEach(m => out.push({ label: m.refresh > 0 ? m.refresh.toFixed(2).replace(/\.?0+$/, "") + " Hz" : "Otomatik", value: m.refresh }));
                return out;
            }
            readonly property bool dirty: selW !== modelData.curW || selH !== modelData.curH || Math.abs(selR - modelData.curR) > 0.001 || selScale !== modelData.scale
            heading: modelData.title + " · " + modelData.name

            SRow {
                label: "Çözünürlük"
                icon: "monitor"
                Dropdown {
                    model: oc.resList
                    current: oc.selW + "x" + oc.selH
                    onPicked: v => {
                        const p = v.split("x");
                        oc.selW = parseInt(p[0]); oc.selH = parseInt(p[1]);
                        const rates = oc.modelData.modes.filter(m => m.width === oc.selW && m.height === oc.selH).map(m => m.refresh);
                        if (rates.indexOf(oc.selR) < 0) oc.selR = Math.max.apply(null, rates);
                    }
                }
            }
            SRow {
                label: "Yenileme hızı"
                icon: "gauge"
                Dropdown {
                    minWidth: 120
                    model: oc.rateList
                    current: oc.selR
                    onPicked: v => oc.selR = v
                }
            }
            SRow {
                label: "Ölçek"
                sub: "Yazı ve öğelerin boyutu"
                icon: "layout-grid"
                Dropdown {
                    minWidth: 120
                    model: [0.75, 1, 1.25, 1.5, 1.75, 2].map(s => ({ label: "%" + Math.round(s * 100), value: s }))
                    current: oc.selScale
                    onPicked: v => oc.selScale = v
                }
            }
            SRow {
                visible: oc.dirty
                label: "Değişiklikler hazır"
                sub: "Uygulanınca bu çıkış yeniden ayarlanır"
                Row {
                    spacing: 8
                    PillButton { text: "Geri al"; onClicked: { oc.selW = oc.modelData.curW; oc.selH = oc.modelData.curH; oc.selR = oc.modelData.curR; oc.selScale = oc.modelData.scale; } }
                    PillButton {
                        text: "Uygula"; kind: "primary"; busy: oc.applying
                        onClicked: {
                            oc.applying = true;
                            const mode = oc.selW + "x" + oc.selH + "@" + oc.selR.toFixed(3) + "Hz";
                            Sh.run(["wlr-randr", "--output", oc.modelData.name, "--mode", mode, "--scale", String(oc.selScale)], (code, out, err) => {
                                oc.applying = false;
                                if (code === 0) {
                                    Sh.iniBatch([
                                        { s: "output:" + oc.modelData.name, k: "mode", v: oc.selW + "x" + oc.selH + "@" + Math.round(oc.selR * 1000) },
                                        { s: "output:" + oc.modelData.name, k: "scale", v: oc.selScale }
                                    ]);
                                    Sh.toast("Ekran ayarı uygulandı");
                                    pg.load();
                                } else Sh.toast("Uygulanamadı");
                            });
                        }
                    }
                }
            }
        }
    }

    Card {
        heading: "Gece ışığı"
        footnote: "Akşamları ekranın mavi ışığını azaltır (wlsunset)."
        SRow {
            label: "Gece ışığı"
            sub: "Ekranı sıcak tonlara çevirir"
            icon: "moon"
            Toggle {
                checked: Sh.get("nightlight", false)
                onToggled: v => {
                    Sh.set("nightlight", v);
                    Sh.sh("pkill -x wlsunset; " + (v ? "setsid wlsunset -t " + Sh.get("nightTemp", 3800) + " -T 6500 -S 00:00 -s 00:01 >/dev/null 2>&1 &" : "true"), null);
                }
            }
        }
        SRow {
            label: "Sıcaklık"
            icon: "thermometer"
            visible: Sh.get("nightlight", false)
            Segmented {
                segWidth: 80
                model: [{ label: "Hafif", value: 4500 }, { label: "Orta", value: 3800 }, { label: "Güçlü", value: 3000 }]
                currentIndex: Math.max(0, [4500, 3800, 3000].indexOf(Sh.get("nightTemp", 3800)))
                onPicked: (i, v) => {
                    Sh.set("nightTemp", v);
                    Sh.sh("pkill -x wlsunset; setsid wlsunset -t " + v + " -T 6500 -S 00:00 -s 00:01 >/dev/null 2>&1 &", null);
                }
            }
        }
    }
}
