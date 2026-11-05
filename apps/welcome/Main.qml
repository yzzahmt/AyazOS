import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import AyazOS.UI
import AyazOS.Native
import "components"

// AyazOS Hoş geldin: ilk açılış karşılama uygulaması
Window {
    id: win
    width: 960
    height: 640
    minimumWidth: 960; maximumWidth: 960
    minimumHeight: 640; maximumHeight: 640
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Hoş geldin"

    // ---------- Durum ----------
    readonly property string confDir: Fs.home + "/.config/ayazos"
    readonly property string cfgPath: confDir + "/shell.json"
    readonly property string donePath: confDir + "/welcome.done"
    readonly property string appDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    readonly property string defaultWp: "/usr/share/backgrounds/ayazos/default.jpg"
    readonly property var accents: ["#A9C1F2", "#8B5CF6", "#5EC8C0", "#F2A0C0", "#F2B66D", "#7BD88F"]

    property int step: 0
    property var cfg: ({})
    readonly property color accent: cfg.accent ? cfg.accent : Theme.accent
    readonly property string wp: cfg.wallpaper ? cfg.wallpaper : defaultWp
    property var wallpapers: []

    // Uygulamalar
    readonly property var appList: [
        { id: "steam", name: "Steam", tag: "Oyun kütüphanen", icon: "gamepad-2", c1: "#1B2A4A", c2: "#2F5D8C", pkg: "steam-installer", fp: "com.valvesoftware.Steam" },
        { id: "discord", name: "Discord", tag: "Sesli ve yazılı sohbet", icon: "mic", c1: "#2A2F5A", c2: "#5865F2", pkg: "", fp: "com.discordapp.Discord" },
        { id: "spotify", name: "Spotify", tag: "Müzik ve podcast", icon: "music-2", c1: "#10351F", c2: "#1DB954", pkg: "", fp: "com.spotify.Client" },
        { id: "vlc", name: "VLC", tag: "Her formatı oynatır", icon: "play", c1: "#4A2F10", c2: "#F08A1C", pkg: "vlc", fp: "org.videolan.VLC" },
        { id: "libreoffice", name: "LibreOffice", tag: "Ofis paketi", icon: "file-text", c1: "#14403A", c2: "#2E9C84", pkg: "libreoffice", fp: "org.libreoffice.LibreOffice" },
        { id: "gimp", name: "GIMP", tag: "Fotoğraf düzenleme", icon: "image", c1: "#3A3220", c2: "#8C7A4A", pkg: "gimp", fp: "org.gimp.GIMP" },
        { id: "obs", name: "OBS Studio", tag: "Kayıt ve yayın", icon: "film", c1: "#2B2B36", c2: "#5C5C78", pkg: "obs-studio", fp: "com.obsproject.Studio" },
        { id: "telegram", name: "Telegram", tag: "Hızlı mesajlaşma", icon: "globe", c1: "#14405A", c2: "#2AABEE", pkg: "telegram-desktop", fp: "org.telegram.desktop" }
    ]
    property var picked: ({})
    readonly property int pickedCount: appList.filter(a => picked[a.id]).length
    property bool installing: false
    property bool installStarted: false
    property var istate: ({})          // id -> { st: wait|run|ok|fail, pct, msg }
    property var queue: []
    property string curId: ""
    property string curSrc: ""
    readonly property int okCount: appList.filter(a => istate[a.id] && istate[a.id].st === "ok").length
    readonly property int failCount: appList.filter(a => istate[a.id] && istate[a.id].st === "fail").length

    readonly property var shortcuts: [
        { keys: ["Super"], label: "Başlat menüsü", icon: "layout-grid" },
        { keys: ["Super", "Tab"], label: "Pencereler", icon: "layers" },
        { keys: ["Super", "E"], label: "Dosyalar", icon: "folder-open" },
        { keys: ["Super", "Enter"], label: "Terminal", icon: "terminal" },
        { keys: ["Super", "L"], label: "Kilitle", icon: "lock" },
        { keys: ["Print"], label: "Ekran görüntüsü", icon: "camera" },
        { keys: ["Super", "Ctrl", "←", "→"], label: "Çalışma alanı", icon: "monitor" },
        { keys: ["3 parmak", "kaydır"], label: "Çalışma alanı", icon: "layout-grid" }
    ]

    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    // ---------- shell.json ----------
    Proc {
        id: cfgRead
        onFinished: (code, out) => { try { win.cfg = JSON.parse(out); } catch (e) { win.cfg = {}; } }
    }
    function loadCfg() { cfgRead.startWith(["sh", "-c", "cat " + q(cfgPath) + " 2>/dev/null"]); }
    // Diğer anahtarları koruyarak yaz: önce diskten oku, birleştir, yaz.
    property var pending: ({})
    Proc {
        id: cfgSave
        onFinished: (code, out) => {
            let c = {};
            try { c = JSON.parse(out); } catch (e) { c = {}; }
            const p = win.pending;
            win.pending = {};
            Object.keys(p).forEach(k => c[k] = p[k]);
            win.cfg = c;
            writer.startWith(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"",
                              "_", JSON.stringify(c, null, 2) + "\n", win.cfgPath]);
        }
    }
    Proc { id: writer }
    function setCfg(key, val) {
        const p = Object.assign({}, pending); p[key] = val; pending = p;
        const c = Object.assign({}, cfg); c[key] = val; cfg = c;
        saveTimer.restart();
    }
    Timer {
        id: saveTimer
        interval: 120
        onTriggered: { if (!cfgSave.running && !writer.running) cfgSave.startWith(["sh", "-c", "cat " + win.q(win.cfgPath) + " 2>/dev/null"]); else saveTimer.restart(); }
    }

    function scanWallpapers() {
        const dirs = ["/usr/share/backgrounds/ayazos", Fs.home + "/AyazOS/branding/wallpapers/thumbs"];
        for (let i = 0; i < dirs.length; i++) {
            if (!Fs.exists(dirs[i])) continue;
            const out = [];
            Array.from(Fs.list(dirs[i], false, "name", false)).forEach(it => {
                if (!it.dir && /\.(jpe?g|png|webp)$/i.test(it.name)) out.push({ path: it.path, name: it.name });
            });
            if (out.length) { wallpapers = out; return; }
        }
    }
    function wpTitle(p) {
        const n = String(p).split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]/g, " ");
        return n.charAt(0).toUpperCase() + n.slice(1);
    }

    // ---------- Gezinme ----------
    function next() {
        if (step < 4) step++;
        else finish();
    }
    function back() { if (step > 0) step--; }
    function finish() {
        doneProc.startWith(["sh", "-c", "mkdir -p " + q(confDir) + " && date -Iseconds > " + q(donePath)]);
    }
    Proc { id: doneProc; onFinished: Qt.quit() }

    // ---------- Yükleme ----------
    readonly property string backend: {
        const cands = [appDir + "../store/bin/ayaz-store-backend", "/usr/share/ayazos/apps/store/bin/ayaz-store-backend"];
        for (let i = 0; i < cands.length; i++) if (Fs.exists(cands[i])) return cands[i];
        return cands[0];
    }
    function setSt(id, st, pct, msg) {
        const s = Object.assign({}, istate);
        s[id] = { st: st, pct: pct, msg: msg };
        istate = s;
    }
    function startInstall() {
        const sel = appList.filter(a => picked[a.id]);
        if (!sel.length || installing) return;
        const s = {};
        sel.forEach(a => s[a.id] = { st: "wait", pct: 0, msg: "Sırada" });
        istate = s;
        queue = sel.map(a => a.id);
        installStarted = true;
        installing = true;
        runNext();
    }
    function appById(id) { return appList.find(a => a.id === id); }
    function runNext() {
        if (queue.length === 0) { installing = false; curId = ""; return; }
        const id = queue[0];
        const a = appById(id);
        curId = id;
        curSrc = a.pkg ? "apt" : "flatpak";
        setSt(id, "run", 0, "Parola bekleniyor");
        instProc.lastOk = null;
        instProc.startWith(["sh", "-c", "python3 " + q(backend) + " install " + q(curSrc === "apt" ? a.pkg : a.fp) + " " + curSrc]);
    }
    Proc {
        id: instProc
        property var lastOk: null
        onLine: text => {
            try {
                const o = JSON.parse(text);
                if (o.type === "progress") win.setSt(win.curId, "run", o.pct, o.msg || "Yükleniyor");
                else if (o.type === "done") lastOk = o.ok;
            } catch (e) {}
        }
        onFinished: (code) => {
            const ok = lastOk !== null ? lastOk : code === 0;
            const id = win.curId;
            const a = win.appById(id);
            if (!ok && win.curSrc === "apt" && a.fp) {
                // apt olmadıysa flatpak dene
                win.curSrc = "flatpak";
                win.setSt(id, "run", 0, "Flatpak deneniyor");
                lastOk = null;
                startWith(["sh", "-c", "python3 " + win.q(win.backend) + " install " + win.q(a.fp) + " flatpak"]);
                return;
            }
            win.setSt(id, ok ? "ok" : "fail", ok ? 100 : 0, ok ? "Yüklendi" : "Yüklenemedi");
            win.queue = win.queue.slice(1);
            win.runNext();
        }
    }

    Component.onCompleted: {
        if (appArgs.length > 0 && appArgs.indexOf("--first-run") >= 0 && Fs.exists(donePath)) { Qt.quit(); return; }
        loadCfg();
        scanWallpapers();
        // geliştirme: --step=N  --pick=steam,vlc
        for (let i = 0; i < appArgs.length; i++) {
            const m = /^--step=(\d)$/.exec(appArgs[i]);
            if (m) step = parseInt(m[1]);
            const pk = /^--pick=(.*)$/.exec(appArgs[i]);
            if (pk) { const p = {}; pk[1].split(",").forEach(x => p[x] = true); picked = p; }
        }
        visible = true;
    }
    Shortcut { sequences: ["Right", "Return"]; onActivated: win.next() }
    Shortcut { sequence: "Left"; onActivated: win.back() }
    Shortcut { sequence: "Escape"; onActivated: win.close() }

    // ---------- Pencere ----------
    Glass {
        id: frame
        anchors.fill: parent
        anchors.margins: 1
        radius: 28
        color: Qt.rgba(11 / 255, 15 / 255, 23 / 255, 0.94)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        // Yumuşak vurgu ışıkları
        SoftGlow { width: 900; height: 900; x: -330; y: -480; color: win.accent; strength: 0.22 }
        SoftGlow { width: 800; height: 800; x: parent.width - 480; y: parent.height - 420; color: Theme.violet; strength: 0.22 }

        MouseArea { anchors { left: parent.left; right: parent.right; top: parent.top } height: 60; onPressed: win.startSystemMove() }
        IconButton { anchors { top: parent.top; right: parent.right; margins: 16 } icon: "x"; size: 34; z: 5; onClicked: win.close() }

        // ---------- Sayfalar ----------
        Item {
            id: pager
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top }
            clip: true

            component PageBox: Item {
                id: pb
                required property int idx
                width: pager.width; height: pager.height
                x: (idx - win.step) * width * 0.6
                opacity: Math.max(0, 1 - Math.abs(idx - win.step))
                visible: opacity > 0.01
                Behavior on x { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
            }

            // 1 — Karşılama
            PageBox {
                idx: 0
                Item {
                    id: hero
                    width: 300; height: 300
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 44 }
                    property real glow: 0
                    SequentialAnimation on glow {
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 2600; easing.type: Easing.InOutSine }
                    }
                    // ışıma
                    SoftGlow {
                        anchors.centerIn: parent
                        width: 520; height: 520
                        color: win.accent
                        strength: 0.34
                        opacity: 0.65 + 0.35 * hero.glow
                    }
                    // yörünge halkası (kuyruklu), döner
                    Item {
                        id: orbitBox
                        anchors.centerIn: parent
                        width: 290; height: 290
                        RotationAnimator on rotation { from: 0; to: 360; duration: 14000; loops: Animation.Infinite; running: win.step === 0 }
                        Canvas {
                            anchors.fill: parent
                            antialiasing: true
                            property color col: win.accent
                            onColChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
                                const r = width / 2 - 8;
                                const n = 100;
                                c.lineWidth = 3;
                                c.lineCap = "round";
                                for (let i = 0; i < n; i++) {
                                    const a0 = (i / n) * Math.PI * 1.5;
                                    const a1 = ((i + 1.6) / n) * Math.PI * 1.5;
                                    const t = i / n;
                                    c.strokeStyle = Qt.rgba(col.r, col.g, col.b, Math.pow(t, 2) * 0.85);
                                    c.beginPath();
                                    c.arc(width / 2, height / 2, r, a0, a1);
                                    c.stroke();
                                }
                            }
                        }
                        // kuyruğun ucundaki parıltı (açı 1.5*PI = üst)
                        Rectangle {
                            x: parent.width / 2 - 6; y: 8 - 6 + 0; width: 12; height: 12; radius: 6
                            color: "#FFFFFF"
                            Rectangle { anchors.centerIn: parent; width: 34; height: 34; radius: 17; color: win.accent; opacity: 0.30; z: -1 }
                        }
                    }
                    Image {
                        id: logo
                        anchors.centerIn: parent
                        width: 190; height: 190
                        source: Qt.resolvedUrl("assets/ayazos-mark.svg")
                        sourceSize: Qt.size(512, 512)
                        smooth: true; mipmap: true
                        SequentialAnimation on anchors.verticalCenterOffset {
                            loops: Animation.Infinite
                            NumberAnimation { from: -8; to: 8; duration: 3200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 8; to: -8; duration: 3200; easing.type: Easing.InOutSine }
                        }
                    }
                }
                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; top: hero.bottom; topMargin: 16 }
                    spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "AyazOS'a hoş geldin"
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 42; weight: Font.Bold; letterSpacing: -0.8 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Kendine alan aç."
                        color: win.accent
                        font { family: Theme.font; pixelSize: 19; weight: Font.Medium }
                    }
                }
            }

            // 2 — Görünüm
            PageBox {
                idx: 1
                Column {
                    anchors { fill: parent; leftMargin: 56; rightMargin: 56; topMargin: 40 }
                    spacing: 6
                    Text { text: "Görünüm"; color: Theme.text; font { family: Theme.font; pixelSize: 30; weight: Font.Bold; letterSpacing: -0.4 } }
                    Text { text: "Masaüstünü sana göre ayarla. Değişiklikler anında uygulanır."; color: Theme.textDim; font { family: Theme.font; pixelSize: 14 } }
                    Item { width: 1; height: 8 }
                    Text { text: "DUVAR KAĞIDI"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.4 } }
                    Grid {
                        id: wpGrid
                        columns: 5
                        spacing: 12
                        readonly property int cw: Math.floor((pager.width - 112 - 4 * 12) / 5)
                        Repeater {
                            model: win.wallpapers.slice(0, 10)
                            Rectangle {
                                required property var modelData
                                readonly property bool sel: win.wp === modelData.path || (win.wp.split("/").pop() === modelData.name)
                                width: wpGrid.cw; height: Math.round(wpGrid.cw * 0.58); radius: 14
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: sel ? 2 : 1
                                border.color: sel ? win.accent : Theme.stroke
                                scale: wm.containsMouse ? 1.03 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.dFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.dFast } }
                                Image {
                                    anchors { fill: parent; margins: 3 }
                                    source: "file://" + modelData.path
                                    sourceSize: Qt.size(320, 200)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                }
                                Rectangle {
                                    visible: parent.sel
                                    anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                                    width: 24; height: 24; radius: 12; color: win.accent
                                    Icon { anchors.centerIn: parent; name: "check"; size: 14; color: Theme.accentInk }
                                }
                                MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.setCfg("wallpaper", modelData.path) }
                            }
                        }
                    }
                    Text {
                        visible: win.wallpapers.length === 0
                        text: "Duvar kağıdı bulunamadı"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 13 }
                    }
                    Item { width: 1; height: 8 }
                    Text { text: "VURGU RENGİ"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.4 } }
                    Row {
                        spacing: 10
                        Repeater {
                            model: win.accents
                            Swatch {
                                required property string modelData
                                swatch: modelData
                                selected: win.accent.toString().toLowerCase() === modelData.toLowerCase()
                                onClicked: win.setCfg("accent", modelData)
                            }
                        }
                    }
                }
            }

            // 3 — Uygulamalar
            PageBox {
                idx: 2
                Column {
                    anchors { fill: parent; leftMargin: 56; rightMargin: 56; topMargin: 40 }
                    spacing: 6
                    Text { text: "Uygulamalar"; color: Theme.text; font { family: Theme.font; pixelSize: 30; weight: Font.Bold; letterSpacing: -0.4 } }
                    Text {
                        text: win.installStarted ? "Seçtiğin uygulamalar sırayla yükleniyor. Her biri için parolan istenebilir." : "İstediklerini seç, hepsini birlikte yükleyelim. Dilersen bu adımı atlayabilirsin."
                        color: Theme.textDim; font { family: Theme.font; pixelSize: 14 }
                    }
                    Item { width: 1; height: 10 }

                    // Seçim kartları
                    Grid {
                        id: appGrid
                        visible: !win.installStarted
                        columns: 4
                        spacing: 14
                        readonly property int cw: Math.floor((pager.width - 112 - 3 * 14) / 4)
                        Repeater {
                            model: win.appList
                            Rectangle {
                                id: card
                                required property var modelData
                                readonly property bool on: !!win.picked[modelData.id]
                                width: appGrid.cw; height: 152; radius: 18
                                color: on ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.14) : (cm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.045))
                                border.width: on ? 2 : 1
                                border.color: on ? win.accent : Theme.stroke
                                scale: cm.pressed ? 0.97 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.dFast } }
                                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.dFast } }
                                Rectangle {
                                    id: tile
                                    anchors { left: parent.left; top: parent.top; margins: 16 }
                                    width: 54; height: 54; radius: 16
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: card.modelData.c1 }
                                        GradientStop { position: 1; color: card.modelData.c2 }
                                    }
                                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                                    Icon { anchors.centerIn: parent; name: card.modelData.icon; size: 26 }
                                }
                                Rectangle {
                                    anchors { right: parent.right; top: parent.top; margins: 14 }
                                    width: 26; height: 26; radius: 13
                                    color: card.on ? win.accent : "transparent"
                                    border.width: 1.5; border.color: card.on ? win.accent : Theme.strokeHi
                                    Behavior on color { ColorAnimation { duration: Theme.dFast } }
                                    Icon { anchors.centerIn: parent; name: "check"; size: 15; color: Theme.accentInk; opacity: card.on ? 1 : 0; scale: card.on ? 1 : 0.4; Behavior on opacity { NumberAnimation { duration: 140 } } Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } } }
                                }
                                Column {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                                    spacing: 2
                                    Text { text: card.modelData.name; color: Theme.text; font { family: Theme.font; pixelSize: 16; weight: Font.DemiBold } }
                                    Text { text: card.modelData.tag; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } elide: Text.ElideRight; width: parent.width }
                                }
                                MouseArea {
                                    id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { const p = Object.assign({}, win.picked); p[card.modelData.id] = !p[card.modelData.id]; win.picked = p; }
                                }
                            }
                        }
                    }

                    // İlerleme listesi
                    Rectangle {
                        visible: win.installStarted
                        width: parent.width; height: win.pickedCount * 42 + 16
                        radius: 18
                        color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Theme.stroke
                        Column {
                            anchors { fill: parent; margins: 8 }
                            Repeater {
                                model: win.appList.filter(a => win.picked[a.id])
                                Item {
                                    id: prow
                                    required property var modelData
                                    readonly property var s: win.istate[modelData.id] || { st: "wait", pct: 0, msg: "Sırada" }
                                    width: parent.width; height: 42
                                    Rectangle {
                                        id: mini
                                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                        width: 30; height: 30; radius: 9
                                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: prow.modelData.c1 }
                                            GradientStop { position: 1; color: prow.modelData.c2 } }
                                        Icon { anchors.centerIn: parent; name: prow.modelData.icon; size: 16 }
                                    }
                                    Text { anchors { left: mini.right; leftMargin: 12; verticalCenter: parent.verticalCenter } text: prow.modelData.name; color: Theme.text; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
                                    Rectangle { // ilerleme çubuğu
                                        visible: prow.s.st === "run"
                                        anchors { right: msgT.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                        width: 160; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.1)
                                        Rectangle { width: parent.width * Math.max(0.04, prow.s.pct / 100); height: parent.height; radius: 3; color: win.accent; Behavior on width { NumberAnimation { duration: 300 } } }
                                    }
                                    Text {
                                        id: msgT
                                        anchors { right: stIcon.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                        text: prow.s.msg
                                        color: prow.s.st === "ok" ? "#7BD88F" : prow.s.st === "fail" ? Theme.danger : Theme.textDim
                                        font { family: Theme.font; pixelSize: 13 }
                                    }
                                    Item {
                                        id: stIcon
                                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                        width: 22; height: 22
                                        Icon { anchors.centerIn: parent; visible: prow.s.st === "ok"; name: "check"; size: 18; color: "#7BD88F" }
                                        Icon { anchors.centerIn: parent; visible: prow.s.st === "fail"; name: "x"; size: 18; color: Theme.danger }
                                        Icon { anchors.centerIn: parent; visible: prow.s.st === "wait"; name: "clock"; size: 16; color: Theme.textFaint }
                                        Icon {
                                            anchors.centerIn: parent; visible: prow.s.st === "run"; name: "refresh-cw"; size: 16; color: win.accent
                                            RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: prow.s.st === "run" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 4 — Kısayollar
            PageBox {
                idx: 3
                Column {
                    anchors { fill: parent; leftMargin: 56; rightMargin: 56; topMargin: 40 }
                    spacing: 6
                    Text { text: "Kısayollar"; color: Theme.text; font { family: Theme.font; pixelSize: 30; weight: Font.Bold; letterSpacing: -0.4 } }
                    Text { text: "Bunları öğrenince her şey parmaklarının ucunda."; color: Theme.textDim; font { family: Theme.font; pixelSize: 14 } }
                    Item { width: 1; height: 12 }
                    Grid {
                        id: scGrid
                        columns: 2
                        spacing: 12
                        readonly property int cw: Math.floor((pager.width - 112 - 12) / 2)
                        Repeater {
                            model: win.shortcuts
                            Rectangle {
                                id: sc
                                required property var modelData
                                required property int index
                                width: scGrid.cw; height: 68; radius: 16
                                color: Qt.rgba(1, 1, 1, 0.045); border.width: 1; border.color: Theme.stroke
                                opacity: win.step === 3 ? 1 : 0
                                transform: Translate { y: win.step === 3 ? 0 : 14; Behavior on y { NumberAnimation { duration: 420 + sc.index * 50; easing.type: Easing.OutCubic } } }
                                Behavior on opacity { NumberAnimation { duration: 300 + sc.index * 60 } }
                                Rectangle {
                                    id: sci
                                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                    width: 40; height: 40; radius: 12
                                    color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.14)
                                    Icon { anchors.centerIn: parent; name: sc.modelData.icon; size: 20; color: win.accent }
                                }
                                Text {
                                    anchors { left: sci.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                    text: sc.modelData.label; color: Theme.text
                                    font { family: Theme.font; pixelSize: 15; weight: Font.Medium }
                                }
                                Row {
                                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                    spacing: 5
                                    Repeater {
                                        model: sc.modelData.keys
                                        Row {
                                            required property string modelData
                                            required property int index
                                            spacing: 5
                                            Text {
                                                visible: index > 0 && modelData !== "→" && modelData !== "kaydır"
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "+"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 13 }
                                            }
                                            Keycap { label: modelData }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5 — Hazırsın
            PageBox {
                idx: 4
                Item {
                    anchors.fill: parent
                    Rectangle {
                        id: okBadge
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 50 }
                        width: 92; height: 92; radius: 46
                        color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.16)
                        border.width: 2; border.color: win.accent
                        scale: win.step === 4 ? 1 : 0.6
                        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
                        Icon { anchors.centerIn: parent; name: "check"; size: 46; color: win.accent }
                    }
                    Text {
                        id: rt
                        anchors { horizontalCenter: parent.horizontalCenter; top: okBadge.bottom; topMargin: 22 }
                        text: "Hazırsın"; color: Theme.text
                        font { family: Theme.font; pixelSize: 36; weight: Font.Bold; letterSpacing: -0.6 }
                    }
                    Text {
                        id: rs
                        anchors { horizontalCenter: parent.horizontalCenter; top: rt.bottom; topMargin: 6 }
                        text: "AyazOS senin için hazır."; color: Theme.textDim
                        font { family: Theme.font; pixelSize: 16 }
                    }
                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; top: rs.bottom; topMargin: 30 }
                        spacing: 14
                        Rectangle {
                            width: 230; height: 76; radius: 16; color: Qt.rgba(1, 1, 1, 0.045); border.width: 1; border.color: Theme.stroke
                            Rectangle {
                                id: sw1; anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                width: 76; height: 48; radius: 10; color: Qt.rgba(1, 1, 1, 0.06); clip: true
                                Image { anchors.fill: parent; source: "file://" + win.wp; sourceSize: Qt.size(200, 130); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            }
                            Column {
                                anchors { left: sw1.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text { text: "Duvar kağıdı"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11 } }
                                Text { text: win.wpTitle(win.wp); color: Theme.text; elide: Text.ElideRight; width: parent.width; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
                            }
                        }
                        Rectangle {
                            width: 200; height: 76; radius: 16; color: Qt.rgba(1, 1, 1, 0.045); border.width: 1; border.color: Theme.stroke
                            Rectangle { id: sw2; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } width: 36; height: 36; radius: 18; color: win.accent }
                            Column {
                                anchors { left: sw2.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text { text: "Vurgu rengi"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11 } }
                                Text { text: String(win.accent).toUpperCase(); color: Theme.text; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
                            }
                        }
                        Rectangle {
                            width: 230; height: 76; radius: 16; color: Qt.rgba(1, 1, 1, 0.045); border.width: 1; border.color: Theme.stroke
                            Rectangle {
                                id: sw3; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                width: 36; height: 36; radius: 11; color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.16)
                                Icon { anchors.centerIn: parent; name: "package"; size: 20; color: win.accent }
                            }
                            Column {
                                anchors { left: sw3.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text { text: "Uygulamalar"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11 } }
                                Text {
                                    width: parent.width; elide: Text.ElideRight; color: Theme.text; font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
                                    text: !win.installStarted ? (win.pickedCount ? win.pickedCount + " uygulama seçili" : "Şimdilik yok")
                                        : win.installing ? "Yükleniyor…"
                                        : win.okCount + " yüklendi" + (win.failCount ? ", " + win.failCount + " olmadı" : "")
                                }
                            }
                        }
                    }
                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; top: rs.bottom; topMargin: 134 }
                        text: "Bu rehbere istediğin zaman Başlat menüsünden “Hoş geldin” diyerek dönebilirsin."
                        color: Theme.textFaint; font { family: Theme.font; pixelSize: 13 }
                    }
                }
            }
        }

        // ---------- Alt çubuk ----------
        Item {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 92
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 40; rightMargin: 40 } height: 1; color: Theme.stroke }

            WBtn {
                anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
                text: "Geri"
                accent: win.accent
                opacity: win.step > 0 ? 1 : 0
                active: win.step > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                onClicked: win.back()
            }
            Row {
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: index === win.step ? 30 : 9; height: 9; radius: 4.5
                        color: index === win.step ? win.accent : (index < win.step ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.45) : Qt.rgba(1, 1, 1, 0.18))
                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 260 } }
                        MouseArea { anchors { fill: parent; margins: -6 } cursorShape: Qt.PointingHandCursor; onClicked: win.step = index }
                    }
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter }
                spacing: 10
                WBtn {
                    visible: win.step === 2 && !win.installStarted && win.pickedCount > 0
                    kind: "secondary"
                    accent: win.accent
                    text: "Seçilenleri yükle (" + win.pickedCount + ")"
                    onClicked: win.startInstall()
                }
                WBtn {
                    kind: "primary"
                    accent: win.accent
                    text: win.step === 4 ? "Başla"
                        : win.step === 0 ? "Başlayalım"
                        : (win.step === 2 && !win.installStarted && win.pickedCount === 0) ? "Atla"
                        : "İleri"
                    onClicked: win.next()
                }
            }
        }
    }
}
