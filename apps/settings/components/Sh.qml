pragma Singleton
import QtQuick
import AyazOS.UI
import AyazOS.Native

// Ortak yardımcılar: komut çalıştırma, shell.json, INI düzenleme, menü/diyalog/bildirim.
QtObject {
    id: root

    // --- Ana pencere tarafından bağlanır ---
    property var menuHost: null
    property var dialogHost: null
    property var toastHost: null

    // --- Yapılandırma ---
    readonly property string confDir: Fs.home + "/.config/ayazos"
    readonly property string cfgPath: confDir + "/shell.json"
    readonly property string iniPath: confDir + "/wayfire.ini"
    property var cfg: ({})
    property bool cfgReady: false
    readonly property color accent: cfg.accent ? cfg.accent : Theme.accent
    readonly property color accentInk: Theme.accentInk

    Component { id: procComp; Proc {} }

    // Komutu sh üzerinden çalıştırır; araç yoksa kod 127 döner (hiç çökmez).
    function run(args, cb) {
        const p = procComp.createObject(root);
        p.finished.connect((code, out, err) => {
            if (cb) cb(code, out, err);
            p.destroy();
        });
        p.startWith(["sh", "-c", "exec \"$@\"", "_"].concat(args));
        return p;
    }
    function sh(script, cb) {
        const p = procComp.createObject(root);
        p.finished.connect((code, out, err) => {
            if (cb) cb(code, out, err);
            p.destroy();
        });
        p.startWith(["sh", "-c", script]);
        return p;
    }
    // Satır satır çıktı gerektiren uzun komutlar
    function stream(script, onLine, cb) {
        const p = procComp.createObject(root);
        p.line.connect(onLine);
        p.finished.connect((code, out, err) => {
            if (cb) cb(code, out, err);
            p.destroy();
        });
        p.startWith(["sh", "-c", script]);
        return p;
    }
    function fire(args) { run(args, null); }

    function writeFileSafe(path, content, cb) {
        const p = procComp.createObject(root);
        p.finished.connect((code, out, err) => { if (cb) cb(code); p.destroy(); });
        p.startWith(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"", "_", content, path]);
    }

    // --- shell.json ---
    function loadCfg() {
        sh("cat '" + cfgPath + "' 2>/dev/null", (code, out) => {
            try { cfg = JSON.parse(out); } catch (e) { cfg = {}; }
            cfgReady = true;
        });
    }
    function get(key, def) { return cfg[key] !== undefined ? cfg[key] : def; }
    function set(key, val) {
        const c = Object.assign({}, cfg);
        c[key] = val;
        cfg = c;
        writeFileSafe(cfgPath, JSON.stringify(c, null, 2) + "\n", null);
    }

    // --- wayfire.ini (sıralı kuyruk; diğer içerik korunur) ---
    property var iniQueue: []
    property bool iniBusy: false
    property var iniText: ""

    function iniApply(text, section, key, value) {
        const lines = text.split("\n");
        const hdr = "[" + section + "]";
        let start = -1, end = lines.length;
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].trim();
            if (t.startsWith("[") && t.endsWith("]")) {
                if (start >= 0) { end = i; break; }
                if (t === hdr) start = i;
            }
        }
        const entry = key + " = " + value;
        if (start < 0) {
            while (lines.length && lines[lines.length - 1].trim() === "") lines.pop();
            lines.push("", hdr, entry, "");
            return lines.join("\n");
        }
        const re = new RegExp("^\\s*" + key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s*=");
        for (let i = start + 1; i < end; i++) {
            if (re.test(lines[i])) { lines[i] = entry; return lines.join("\n"); }
        }
        let last = end - 1;
        while (last > start && lines[last].trim() === "") last--;
        lines.splice(last + 1, 0, entry);
        return lines.join("\n");
    }
    function iniParse(text) {
        const out = {};
        let sec = "";
        text.split("\n").forEach(l => {
            const t = l.trim();
            if (!t || t[0] === "#") return;
            if (t[0] === "[" && t.endsWith("]")) { sec = t.slice(1, -1); out[sec] = out[sec] || {}; return; }
            const i = t.indexOf("=");
            if (i > 0 && sec) out[sec][t.slice(0, i).trim()] = t.slice(i + 1).trim();
        });
        return out;
    }
    readonly property string iniLoadScript:
        "f=\"$HOME/.config/ayazos/wayfire.ini\"; if [ ! -f \"$f\" ]; then mkdir -p \"$(dirname \"$f\")\"; " +
        "cp /etc/ayazos/wayfire.ini \"$f\" 2>/dev/null || cp \"$HOME/AyazOS/session/wayfire.ini\" \"$f\" 2>/dev/null || : > \"$f\"; fi; cat \"$f\""

    function iniRead(cb) { sh(iniLoadScript, (code, out) => cb(iniParse(out))); }
    // Tek yazım: değişiklikler {section, key, value} listesi
    function iniSet(section, key, value) { iniBatch([{ s: section, k: key, v: value }]); }
    function iniBatch(changes) {
        iniQueue = iniQueue.concat([changes]);
        if (!iniBusy) iniNext();
    }
    function iniNext() {
        if (iniQueue.length === 0) { iniBusy = false; return; }
        iniBusy = true;
        const changes = iniQueue[0];
        iniQueue = iniQueue.slice(1);
        sh(iniLoadScript, (code, out) => {
            let text = out;
            changes.forEach(c => { text = iniApply(text, c.s, c.k, String(c.v)); });
            if (!text.endsWith("\n")) text += "\n";
            writeFileSafe(iniPath, text, () => iniNext());
        });
    }

    // --- Arayüz yardımcıları ---
    function menu(anchor, options, current, cb) { if (menuHost) menuHost.open(anchor, options, current, cb); }
    function ask(spec, cb) { if (dialogHost) dialogHost.open(spec, cb); }
    function toast(msg) { if (toastHost) toastHost.show(msg); }

    // "a:b" ayrımı, \: kaçışlarına saygılı (nmcli -t)
    function splitEsc(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }

    Component.onCompleted: loadCfg()
}
