import QtQuick
import AyazOS.UI
import "../components"

Page {
    id: pg
    title: "Klavye ve Fare"
    subtitle: "Düzen, tekrar hızı ve işaretçi davranışı."

    property var ini: ({})
    property bool ready: false
    readonly property var layouts: [
        { label: "Türkçe Q", value: "tr|" }, { label: "Türkçe F", value: "tr|f" }, { label: "İngilizce (ABD)", value: "us|" },
        { label: "İngilizce (BK)", value: "gb|" }, { label: "Almanca", value: "de|" }, { label: "Fransızca", value: "fr|" },
        { label: "İspanyolca", value: "es|" }, { label: "İtalyanca", value: "it|" }, { label: "Rusça", value: "ru|" }, { label: "Azerice", value: "az|" }
    ]
    function g(key, def) { const s = ini["input"]; return s && s[key] !== undefined ? s[key] : def; }
    function gb(key, def) { return String(g(key, def)) === "true"; }
    function put(key, val) {
        const c = Object.assign({}, ini);
        c["input"] = Object.assign({}, c["input"] || {});
        c["input"][key] = String(val);
        ini = c;
        Sh.iniSet("input", key, val);
    }
    function load() { Sh.iniRead(r => { ini = r; ready = true; }); }
    Component.onCompleted: load()

    Card {
        heading: "Klavye"
        SRow {
            label: "Klavye düzeni"
            sub: "Anında uygulanır"
            icon: "languages"
            Dropdown {
                minWidth: 180
                model: pg.layouts
                current: pg.g("xkb_layout", "tr") + "|" + pg.g("xkb_variant", "")
                onPicked: v => { const p = v.split("|"); pg.put("xkb_layout", p[0]); pg.put("xkb_variant", p[1]); }
            }
        }
        SRow {
            label: "Tekrar hızı"
            sub: "Tuşa basılı tutunca saniyedeki karakter"
            icon: "keyboard"
            Slider {
                from: 10; to: 60; stepSize: 1; showValue: true
                value: parseInt(pg.g("kb_repeat_rate", 40))
                onReleased: v => pg.put("kb_repeat_rate", Math.round(v))
            }
        }
        SRow {
            label: "Tekrar gecikmesi"
            sub: "İlk tekrardan önce beklenen süre"
            Slider {
                from: 150; to: 700; stepSize: 10; showValue: true; suffix: " ms"
                value: parseInt(pg.g("kb_repeat_delay", 280))
                onReleased: v => pg.put("kb_repeat_delay", Math.round(v))
            }
        }
        SRow {
            label: "Deneme alanı"
            Field { width: 280; placeholder: "Buraya yazarak dene" }
        }
    }

    Card {
        heading: "Dokunmatik yüzey ve fare"
        SRow {
            label: "Doğal kaydırma"
            sub: "İçerik parmağını izler"
            icon: "mouse-pointer-2"
            Toggle { checked: pg.gb("natural_scroll", false); onToggled: v => pg.put("natural_scroll", v) }
        }
        SRow {
            label: "Dokunarak tıkla"
            sub: "Dokunmatik yüzeye dokunmak tıklama sayılır"
            Toggle { checked: pg.gb("tap_to_click", true); onToggled: v => pg.put("tap_to_click", v) }
        }
        SRow {
            label: "Yazarken yüzeyi devre dışı bırak"
            Toggle { checked: pg.gb("disable_touchpad_while_typing", true); onToggled: v => pg.put("disable_touchpad_while_typing", v) }
        }
        SRow {
            label: "İşaretçi hızı"
            Slider {
                from: -1; to: 1; stepSize: 0.1; showValue: true; decimals: 1
                value: parseFloat(pg.g("mouse_cursor_speed", 0))
                onReleased: v => { const r = Math.round(v * 10) / 10; pg.put("mouse_cursor_speed", r); pg.put("touchpad_cursor_speed", r); }
            }
        }
    }
}
