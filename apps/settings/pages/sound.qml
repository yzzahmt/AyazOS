import QtQuick
import AyazOS.UI
import "../components"

Page {
    id: pg
    title: "Ses"
    subtitle: "Çıkış, giriş aygıtları ve ses düzeyi."

    property var sinks: []
    property var sources: []
    property bool unavailable: false
    property bool loaded: false

    function parse(out) {
        const res = { sinks: [], sources: [] };
        let sec = "", inAudio = false;
        out.split("\n").forEach(l => {
            if (/^Audio/.test(l)) { inAudio = true; return; }
            if (/^(Video|Settings)/.test(l)) { inAudio = false; return; }
            if (!inAudio) return;
            const h = l.match(/[├└]─\s+([A-Za-z ]+):/);
            if (h) { sec = h[1].trim(); return; }
            if (sec !== "Sinks" && sec !== "Sources") return;
            const m = l.match(/^[\s│]*(\*)?\s*(\d+)\.\s+(.+?)(?:\s+\[vol:\s*([\d.]+)(\s+MUTED)?\])?\s*$/);
            if (!m) return;
            (sec === "Sinks" ? res.sinks : res.sources).push({ id: m[2], name: m[3], def: !!m[1], vol: m[4] ? parseFloat(m[4]) : 0, muted: !!m[5] });
        });
        return res;
    }
    function load() {
        Sh.run(["wpctl", "status"], (code, out) => {
            loaded = true;
            if (code !== 0) { unavailable = true; return; }
            const r = parse(out);
            sinks = r.sinks; sources = r.sources;
            unavailable = false;
        });
    }
    Component.onCompleted: load()
    Timer { interval: 4000; running: true; repeat: true; onTriggered: if (!pg.pendingSet) pg.load() }
    property bool pendingSet: false

    function setVol(id, v) { pendingSet = true; Sh.run(["wpctl", "set-volume", id, v.toFixed(2)], () => pendingSet = false); }
    function setMute(id, m) { Sh.run(["wpctl", "set-mute", id, m ? "1" : "0"], () => load()); }
    function setDefault(id) { Sh.run(["wpctl", "set-default", id], () => load()); }

    Text {
        visible: pg.loaded && pg.unavailable
        text: "Kullanılamıyor — ses hizmeti (PipeWire) çalışmıyor."
        color: Theme.textDim
        font { family: Theme.font; pixelSize: 14 }
    }

    Repeater {
        model: [{ kind: "sinks", head: "Çıkış", icon: "volume-2", off: "volume-x", none: "Çıkış aygıtı yok" },
                { kind: "sources", head: "Giriş", icon: "mic", off: "mic", none: "Giriş aygıtı yok" }]
        Card {
            id: sc
            required property var modelData
            readonly property var devs: modelData.kind === "sinks" ? pg.sinks : pg.sources
            readonly property var def: devs.find(d => d.def) || devs[0]
            visible: !pg.unavailable
            heading: modelData.head

            SRow {
                visible: sc.def !== undefined
                label: sc.def ? sc.def.name : ""
                sub: "Ses düzeyi"
                icon: sc.def && sc.def.muted ? modelData.off : modelData.icon
                Row {
                    spacing: 14
                    Slider {
                        width: 220
                        showValue: true; suffix: "%"
                        value: sc.def ? sc.def.vol * 100 : 0
                        from: 0; to: 100; stepSize: 1
                        onMoved: v => { if (sc.def) pg.setVol(sc.def.id, v / 100); }
                    }
                    Toggle { checked: sc.def ? !sc.def.muted : true; onToggled: v => pg.setMute(sc.def.id, !v) }
                }
            }
            SRow { visible: sc.devs.length === 0; label: modelData.none }
            Repeater {
                model: sc.devs.length > 1 ? sc.devs : []
                SRow {
                    required property var modelData
                    label: modelData.name
                    clickable: true
                    highlight: modelData.def
                    onClicked: pg.setDefault(modelData.id)
                    Icon { visible: modelData.def; name: "check"; size: 18; color: Sh.accent }
                }
            }
        }
    }
}
