import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import AyazOS.UI
import AyazOS.Native

// AyazOS Yazılım Merkezi
Window {
    id: win
    width: 1240
    height: 820
    minimumWidth: 900
    minimumHeight: 580
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Yazılım Merkezi"

    // --- durum ---
    readonly property string appDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    readonly property string backend: "python3 " + appDir + "bin/ayaz-store-backend"
    property string page: "home"          // home | category | search | installed | updates | detail
    property string prevPage: "home"
    property string catId: ""
    property var catalog: ({ apps: {}, rows: [], hero: [], categories: [] })
    property var iconMap: ({})
    property bool flatpakOn: false
    property var results: []
    property bool loading: false
    property string query: ""
    property var installedList: []
    property var updates: []
    property bool updChecked: false
    property bool updBusy: false
    property string updLog: ""
    property var cur: ({})                // açık uygulama
    property var det: ({})                // ayrıntılar
    property string src: "apt"            // seçili kaynak
    property bool busy: false
    property real pct: 0
    property string pmsg: ""
    property string notice: ""
    property bool noticeOk: true
    property int heroIdx: 0

    function sh(cmd) { return ["sh", "-c", cmd]; }
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function parseLines(out) {
        const r = [];
        out.split("\n").forEach(l => { if (l.trim()) { try { r.push(JSON.parse(l)); } catch (e) {} } });
        return r;
    }
    function hashColor(s, light) {
        let h = 0;
        for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360, 0.45, light ? 0.42 : 0.2, 1);
    }
    function fromCatalog(key) {
        const a = catalog.apps[key];
        if (!a) return null;
        return {
            key: key, name: a.name, summary: a.tagline, pkg: a.pkg, flatpak: a.flatpak, iconName: a.icon,
            icon: iconMap[a.icon] || "", lucide: a.lucide, c1: a.c1, c2: a.c2, dev: a.dev || "", curated: true
        };
    }
    function fromBackend(o) {
        return {
            key: o.id, name: o.name, summary: o.summary, pkg: o.pkg, flatpak: o.source === "flatpak" ? o.id : "",
            iconName: "", icon: o.icon, lucide: "package", c1: hashColor(o.name, false), c2: hashColor(o.name, true),
            dev: "", curated: false, installed: o.installed, source: o.source
        };
    }
    function go(p, c) {
        if (p !== "detail") prevPage = p;
        page = p;
        notice = "";
        if (c !== undefined) catId = c;
        if (p === "category") runList(["category", c]);
        else if (p === "installed") { loading = true; instProc.startWith(sh(backend + " installed")); }
        else if (p === "updates") checkUpdates();
        else if (p === "home") { searchBox.text = ""; query = ""; }
    }
    function runList(args) {
        results = [];
        loading = true;
        listProc.kill();
        listProc.startWith(sh(backend + " " + args.map(q).join(" ")));
    }
    function openApp(a, autoInstall) {
        cur = a;
        det = {};
        src = a.flatpak && !a.pkg ? "flatpak" : "apt";
        busy = false; pct = 0; notice = "";
        page = "detail";
        detProc.startWith(sh(backend + " details " + q(a.key) + " " + q(a.pkg || "") + " " + q(a.flatpak || "")));
        wantInstall = !!autoInstall;
    }
    property bool wantInstall: false
    function installed(d) { return d.apt_installed || d.flatpak_installed; }
    function aptOk() { return det.apt_available; }
    function fpOk() { return det.flatpak_available; }
    function doInstall() {
        if (busy) return;
        if (!aptOk() && !fpOk()) { notice = "Bu uygulama bu bilgisayarda şu an bulunamadı."; noticeOk = false; return; }
        if (src === "apt" && !aptOk()) src = "flatpak";
        if (src === "flatpak" && !fpOk()) src = "apt";
        busy = true; pct = 0; pmsg = "Hazırlanıyor"; notice = "";
        actProc.mode = "install";
        const id = src === "apt" ? cur.pkg : cur.flatpak;
        actProc.startWith(sh(backend + " install " + q(id) + " " + src));
    }
    function doRemove(id, source, pkgOrApp) {
        if (busy) return;
        busy = true; pct = 0; pmsg = "Hazırlanıyor"; notice = "";
        actProc.mode = "remove";
        actProc.startWith(sh(backend + " remove " + q(id) + " " + source));
    }
    function doOpen() {
        const s = det.apt_installed ? "apt" : "flatpak";
        const id = s === "apt" ? (cur.key.indexOf(".") > 0 || !cur.curated ? cur.key : cur.pkg) : cur.flatpak;
        Proc.detached(sh(backend + " launch " + q(id) + " " + s));
    }
    function checkUpdates() {
        loading = true;
        updProc.startWith(sh("U=$(command -v ayaz-update || echo ~/AyazOS/repo/ayaz-update); exec \"$U\" list"));
    }

    Component.onCompleted: {
        catProc.startWith(["cat", appDir + "catalog.json"]);
        metaProc.startWith(sh(backend + " meta"));
        updProc.startWith(sh("U=$(command -v ayaz-update || echo ~/AyazOS/repo/ayaz-update); exec \"$U\" list"));
    }

    Proc {
        id: catProc
        onFinished: (code, out) => {
            try { win.catalog = JSON.parse(out); } catch (e) {}
            const names = Object.keys(win.catalog.apps).map(k => win.catalog.apps[k].icon);
            iconProc.startWith(win.sh(win.backend + " icons " + names.map(win.q).join(" ")));
        }
    }
    Proc {
        id: iconProc
        onFinished: (code, out) => {
            const r = win.parseLines(out);
            if (r.length) win.iconMap = r[0].map;
        }
    }
    Proc { id: metaProc; onFinished: (code, out) => { const r = win.parseLines(out); if (r.length) win.flatpakOn = r[0].flatpak; } }
    Proc {
        id: listProc
        onFinished: (code, out) => {
            if (code !== 0 && code !== 1) return;
            win.results = win.parseLines(out).filter(o => o.type === "app").map(win.fromBackend);
            win.loading = false;
        }
    }
    Proc {
        id: instProc
        onFinished: (code, out) => {
            win.installedList = win.parseLines(out).filter(o => o.type === "app").map(win.fromBackend);
            win.loading = false;
        }
    }
    Proc {
        id: detProc
        onFinished: (code, out) => {
            const r = win.parseLines(out).filter(o => o.type === "details");
            if (r.length) {
                win.det = r[0];
                if (win.src === "apt" && !r[0].apt_available && r[0].flatpak_available) win.src = "flatpak";
                if (win.wantInstall && !win.installed(r[0])) { win.wantInstall = false; win.doInstall(); }
            }
        }
    }
    Proc {
        id: actProc
        property string mode: "install"
        onLine: text => {
            try {
                const o = JSON.parse(text);
                if (o.type === "progress") { win.pct = o.pct; win.pmsg = o.msg; }
            } catch (e) {}
        }
        onFinished: (code, out) => {
            const done = win.parseLines(out).filter(o => o.type === "done");
            const ok = done.length ? done[done.length - 1].ok : code === 0;
            win.busy = false;
            win.noticeOk = ok;
            win.notice = ok ? (mode === "install" ? "Yükleme tamamlandı." : "Kaldırma tamamlandı.")
                            : (mode === "install" ? "Yükleme tamamlanamadı. Yetki penceresi iptal edilmiş veya bağlantı kopmuş olabilir." : "Kaldırma tamamlanamadı.");
            if (win.page === "detail") detProc.startWith(win.sh(win.backend + " details " + win.q(win.cur.key) + " " + win.q(win.cur.pkg || "") + " " + win.q(win.cur.flatpak || "")));
            else if (win.page === "installed") win.go("installed");
        }
    }
    Proc {
        id: updProc
        onFinished: (code, out) => {
            win.updates = out.split("\n").filter(l => l.trim()).map(l => {
                const m = l.match(/^([^\/\s]+)\/\S+\s+(\S+)\s+\S+\s*(?:\[upgradable from: (.*)\])?/);
                return m ? { name: m[1], ver: m[2], old: m[3] || "" } : null;
            }).filter(x => x);
            win.updChecked = true;
            win.loading = false;
        }
    }
    Proc {
        id: applyProc
        onLine: text => { win.updLog = text; }
        onFinished: (code, out) => {
            win.updBusy = false;
            win.noticeOk = code === 0;
            win.notice = code === 0 ? "Sistem güncel." : "Güncelleme tamamlanamadı.";
            win.checkUpdates();
        }
    }

    Timer { interval: 6500; running: win.page === "home"; repeat: true; onTriggered: win.heroIdx = (win.heroIdx + 1) % Math.max(1, win.catalog.hero.length) }
    Timer { id: searchDelay; interval: 350; onTriggered: { if (win.query.length < 2) return; win.page = "search"; win.runList(["search", win.query]); } }
    Shortcut { sequences: ["Ctrl+K", "Ctrl+F"]; onActivated: searchBox.forceActiveFocus() }

    // ================= Görünüm =================
    Glass {
        id: frame
        anchors.fill: parent
        anchors.margins: win.visibility === Window.Maximized ? 0 : 1
        radius: win.visibility === Window.Maximized ? 0 : Theme.rWindow
        color: Qt.rgba(13 / 255, 17 / 255, 25 / 255, 0.90)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        clip: true

        // --- Başlık çubuğu ---
        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 74
            MouseArea {
                anchors.fill: parent
                onPressed: win.startSystemMove()
                onDoubleClicked: win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 24; rightMargin: 18 }
                spacing: 6
                RowLayout {
                    Layout.preferredWidth: 212
                    spacing: 12
                    Icon { name: "shopping-bag"; size: 22 }
                    Text { text: "Yazılım Merkezi"; color: Theme.text; font { family: Theme.font; pixelSize: 17; weight: Font.DemiBold } }
                }
                IconButton {
                    icon: "chevron-left"; size: 32
                    opacity: win.page === "detail" ? 1 : 0.35
                    onClicked: if (win.page === "detail") win.go(win.prevPage)
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 340; Layout.preferredHeight: 40
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: searchBox.activeFocus ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.45) : Theme.stroke
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                        spacing: 8
                        Icon { name: "search"; size: 16; color: Theme.textDim }
                        TextInput {
                            id: searchBox
                            Layout.fillWidth: true
                            color: Theme.text
                            clip: true
                            font { family: Theme.font; pixelSize: 13 }
                            onTextEdited: { win.query = text; if (text.length < 2 && win.page === "search") win.go("home"); else searchDelay.restart(); }
                            Keys.onEscapePressed: { text = ""; win.go("home"); focus = false; }
                            Text {
                                visible: !searchBox.text
                                text: "Uygulama ara"
                                color: Theme.textFaint
                                font: searchBox.font
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text { visible: !searchBox.text; text: "Ctrl K"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11 } }
                    }
                }
                Item { Layout.preferredWidth: 14 }
                IconButton { icon: "minus"; size: 34; onClicked: win.showMinimized() }
                IconButton { icon: "maximize-2"; size: 34; iconSize: 16; onClicked: win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized() }
                IconButton { icon: "x"; size: 34; onClicked: win.close() }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.stroke }
        }

        // --- Kenar çubuğu ---
        Item {
            id: sidebar
            anchors { left: parent.left; top: header.bottom; bottom: parent.bottom }
            width: 236
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.stroke }
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 28 }
                spacing: 4
                SectionLabel { text: "KEŞFET" }
                NavItem { icon: "compass"; label: "Keşfet"; active: win.page === "home"; onClicked: win.go("home") }
                NavItem { icon: "download"; label: "Yüklü"; active: win.page === "installed"; onClicked: win.go("installed") }
                NavItem { icon: "refresh-cw"; label: "Güncellemeler"; badge: win.updates.length; active: win.page === "updates"; onClicked: win.go("updates") }
                Item { width: 1; height: 8 }
                Rectangle { width: parent.width; height: 1; color: Theme.stroke; opacity: 0.8 }
                Item { width: 1; height: 6 }
                SectionLabel { text: "KATEGORİLER" }
                Repeater {
                    model: win.catalog.categories
                    NavItem {
                        required property var modelData
                        icon: modelData.icon; label: modelData.label
                        active: win.page === "category" && win.catId === modelData.id
                        onClicked: win.go("category", modelData.id)
                    }
                }
            }
        }

        // --- İçerik ---
        Item {
            id: content
            anchors { left: sidebar.right; right: parent.right; top: header.bottom; bottom: parent.bottom }

            // ===== Keşfet =====
            Flickable {
                id: homeFlick
                anchors.fill: parent
                visible: win.page === "home"
                contentHeight: homeCol.height + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: homeCol
                    x: 34; y: 28
                    width: content.width - 68
                    spacing: 30

                    // Büyük vitrin
                    Item {
                        width: parent.width; height: 270
                        Repeater {
                            model: win.catalog.hero
                            Rectangle {
                                id: hero
                                required property string modelData
                                required property int index
                                readonly property var app: win.fromCatalog(modelData) || ({ name: "", summary: "", c1: "#000", c2: "#000", lucide: "package" })
                                anchors.fill: parent
                                radius: 22
                                opacity: win.heroIdx === index ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: hero.app.c1 }
                                    GradientStop { position: 1; color: hero.app.c2 }
                                }
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                                Icon {
                                    name: hero.app.lucide; size: 300; color: "#FFFFFF"
                                    opacity: 0.07
                                    anchors { right: parent.right; rightMargin: -30; verticalCenter: parent.verticalCenter }
                                }
                                Rectangle {
                                    anchors.fill: parent; radius: 22
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.08) }
                                        GradientStop { position: 0.5; color: "transparent" }
                                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.28) }
                                    }
                                }
                                AppIcon { app: hero.app; size: 150; anchors { right: parent.right; rightMargin: 64; verticalCenter: parent.verticalCenter } }
                                Column {
                                    anchors { left: parent.left; leftMargin: 44; verticalCenter: parent.verticalCenter }
                                    width: parent.width - 330
                                    spacing: 10
                                    Text { text: "ÖNE ÇIKAN"; color: Qt.rgba(1, 1, 1, 0.7); font { family: Theme.font; pixelSize: 11; letterSpacing: 1.6; weight: Font.Medium } }
                                    Text { text: hero.app.name; color: "white"; font { family: Theme.font; pixelSize: 40; weight: Font.DemiBold } width: parent.width; elide: Text.ElideRight }
                                    Text { text: hero.app.summary; color: Qt.rgba(1, 1, 1, 0.82); font { family: Theme.font; pixelSize: 17 } width: parent.width; wrapMode: Text.WordWrap }
                                    Item { width: 1; height: 8 }
                                    PrimaryButton { label: "Yükle"; icon: "download"; onClicked: win.openApp(hero.app, true) }
                                }
                                MouseArea { anchors.fill: parent; z: -1; onClicked: win.openApp(hero.app, false) }
                            }
                        }
                        Row {
                            anchors { left: parent.left; leftMargin: 44; bottom: parent.bottom; bottomMargin: 18 }
                            spacing: 7
                            Repeater {
                                model: win.catalog.hero.length
                                Rectangle {
                                    required property int index
                                    width: win.heroIdx === index ? 22 : 7; height: 7; radius: 3.5
                                    color: win.heroIdx === index ? "white" : Qt.rgba(1, 1, 1, 0.4)
                                    Behavior on width { NumberAnimation { duration: Theme.dNormal } }
                                    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: win.heroIdx = index }
                                }
                            }
                        }
                    }

                    // Seçki satırları
                    Repeater {
                        model: win.catalog.rows
                        Column {
                            required property var modelData
                            width: homeCol.width
                            spacing: 14
                            Text { text: modelData.title; color: Theme.text; font { family: Theme.font; pixelSize: 20; weight: Font.Medium } }
                            ListView {
                                width: parent.width; height: 100
                                orientation: ListView.Horizontal
                                spacing: 14
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: modelData.ids
                                delegate: AppCard {
                                    required property string modelData
                                    app: win.fromCatalog(modelData) || ({ name: modelData, summary: "", key: modelData, lucide: "package", c1: "#222", c2: "#444" })
                                    onClicked: win.openApp(app, false)
                                }
                            }
                        }
                    }
                }
            }

            // ===== Liste sayfaları (kategori / arama / yüklü) =====
            Item {
                anchors.fill: parent
                visible: win.page === "category" || win.page === "search" || win.page === "installed"
                readonly property var items: win.page === "installed" ? win.installedList : win.results
                Column {
                    id: lHead
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 34; rightMargin: 32; topMargin: 32 }
                    spacing: 6
                    Text {
                        color: Theme.text; font { family: Theme.font; pixelSize: 28 }
                        text: {
                            if (win.page === "installed") return "Yüklü uygulamalar";
                            if (win.page === "search") return "Arama";
                            for (const c of win.catalog.categories) if (c.id === win.catId) return c.label;
                            return "";
                        }
                    }
                    Text {
                        color: Theme.textDim; font { family: Theme.font; pixelSize: 13 }
                        text: win.loading ? "Yükleniyor…" : (win.page === "search" ? "“" + win.query + "” için " + parent.parent.items.length + " sonuç" : parent.parent.items.length + " uygulama")
                    }
                }
                ListView {
                    anchors { left: parent.left; right: parent.right; top: lHead.bottom; bottom: parent.bottom; topMargin: 22; leftMargin: 34; rightMargin: 32 }
                    clip: true
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    model: parent.items
                    bottomMargin: 24
                    delegate: ListRow {
                        required property var modelData
                        app: modelData
                        removable: win.page === "installed"
                        onClicked: win.openApp(app, false)
                    }
                }
                Column {
                    visible: !win.loading && parent.items.length === 0
                    anchors.centerIn: parent
                    spacing: 12
                    Icon { name: win.page === "installed" ? "package" : "search"; size: 44; color: Theme.textFaint; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: win.page === "installed" ? "Henüz yüklediğin uygulama yok" : "Sonuç bulunamadı"; color: Theme.textDim; font { family: Theme.font; pixelSize: 15 } anchors.horizontalCenter: parent.horizontalCenter }
                }
                Busy { visible: win.loading; anchors.centerIn: parent }
            }

            // ===== Güncellemeler =====
            Item {
                anchors.fill: parent
                visible: win.page === "updates"
                RowLayout {
                    id: uHead
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 34; rightMargin: 32; topMargin: 32 }
                    Column {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: "Güncellemeler"; color: Theme.text; font { family: Theme.font; pixelSize: 28 } }
                        Text {
                            color: Theme.textDim; font { family: Theme.font; pixelSize: 13 }
                            text: win.updBusy ? (win.updLog || "Güncelleniyor…") : win.loading ? "Denetleniyor…" : win.updates.length > 0 ? win.updates.length + " güncelleme hazır" : "Her şey güncel"
                        }
                    }
                    PrimaryButton {
                        visible: win.updates.length > 0 && !win.updBusy
                        label: "Tümünü güncelle"; icon: "refresh-cw"
                        onClicked: { win.updBusy = true; win.updLog = ""; win.notice = ""; applyProc.startWith(win.sh("U=$(command -v ayaz-update || echo ~/AyazOS/repo/ayaz-update); exec \"$U\" apply 2>&1")); }
                    }
                    GhostButton { visible: !win.updBusy; label: "Denetle"; icon: "rotate-ccw"; onClicked: win.checkUpdates() }
                }
                Rectangle {
                    id: uBar
                    visible: win.updBusy
                    anchors { left: parent.left; right: parent.right; top: uHead.bottom; leftMargin: 34; rightMargin: 32; topMargin: 18 }
                    height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.08); clip: true
                    Rectangle {
                        width: 160; height: parent.height; radius: 2; color: Theme.accent
                        SequentialAnimation on x { running: win.updBusy; loops: Animation.Infinite
                            NumberAnimation { from: -160; to: uBar.width; duration: 1400; easing.type: Easing.InOutQuad } }
                    }
                }
                ListView {
                    anchors { left: parent.left; right: parent.right; top: uHead.bottom; bottom: parent.bottom; topMargin: 34; leftMargin: 34; rightMargin: 32 }
                    clip: true; spacing: 6; bottomMargin: 24
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.updates
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 56; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.035); border.width: 1; border.color: Theme.stroke
                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                            spacing: 12
                            Icon { name: "package"; size: 18; color: Theme.textDim }
                            Text { text: modelData.name; color: Theme.text; Layout.fillWidth: true; elide: Text.ElideRight; font { family: Theme.font; pixelSize: 14 } }
                            Text { text: (modelData.old ? modelData.old + "  →  " : "") + modelData.ver; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                        }
                    }
                }
                Column {
                    visible: !win.loading && win.updChecked && win.updates.length === 0
                    anchors.centerIn: parent
                    spacing: 12
                    Icon { name: "shield-check"; size: 52; color: Theme.accent; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "Sistemin güncel"; color: Theme.text; font { family: Theme.font; pixelSize: 18 } anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "Yeni bir güncelleme olduğunda burada görünür."; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } anchors.horizontalCenter: parent.horizontalCenter }
                }
                Busy { visible: win.loading && !win.updBusy; anchors.centerIn: parent }
                Toast { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }; visible: win.notice !== "" && win.page === "updates" }
            }

            // ===== Ayrıntı =====
            Flickable {
                id: detFlick
                anchors.fill: parent
                visible: win.page === "detail"
                contentHeight: detCol.height + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: detCol
                    x: 40; y: 34
                    width: content.width - 80
                    spacing: 26

                    Rectangle {
                        width: parent.width; height: 200; radius: 22
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: win.cur.c1 || "#222" }
                            GradientStop { position: 1; color: win.cur.c2 || "#444" }
                        }
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                        clip: true
                        Icon { name: win.cur.lucide || "package"; size: 260; color: "#FFFFFF"; opacity: 0.07; anchors { right: parent.right; rightMargin: -20; verticalCenter: parent.verticalCenter } }
                        Rectangle { anchors.fill: parent; radius: 22; gradient: Gradient { GradientStop { position: 0.4; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.3) } } }
                        AppIcon { id: dIcon; app: win.cur; size: 112; anchors { left: parent.left; leftMargin: 36; verticalCenter: parent.verticalCenter } }
                        Column {
                            anchors { left: dIcon.right; leftMargin: 28; right: actions.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Text { text: win.cur.name || ""; color: "white"; width: parent.width; elide: Text.ElideRight; font { family: Theme.font; pixelSize: 32; weight: Font.DemiBold } }
                            Text { text: win.det.developer || win.cur.dev || ""; visible: text !== ""; color: Qt.rgba(1, 1, 1, 0.75); font { family: Theme.font; pixelSize: 14 } }
                            Row {
                                spacing: 8
                                Badge { visible: win.det.apt_available === true; text: "APT"; on: win.src === "apt"; onClicked: if (!win.busy) win.src = "apt" }
                                Badge { visible: win.det.flatpak_available === true; text: "Flatpak"; on: win.src === "flatpak"; onClicked: if (!win.busy) win.src = "flatpak" }
                                Badge { visible: win.installed(win.det); text: "Yüklü"; on: true; check: true }
                            }
                        }
                        Column {
                            id: actions
                            anchors { right: parent.right; rightMargin: 36; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            width: 190
                            PrimaryButton {
                                width: parent.width
                                visible: !win.busy && !win.installed(win.det)
                                label: "Yükle"; icon: "download"
                                onClicked: win.doInstall()
                            }
                            PrimaryButton {
                                width: parent.width
                                visible: !win.busy && win.installed(win.det)
                                label: "Aç"; icon: "external-link"
                                onClicked: win.doOpen()
                            }
                            GhostButton {
                                width: parent.width
                                visible: !win.busy && win.installed(win.det)
                                label: "Kaldır"; icon: "trash-2"; danger: true
                                onClicked: win.doRemove(win.det.apt_installed ? win.cur.pkg : win.cur.flatpak, win.det.apt_installed ? "apt" : "flatpak")
                            }
                            Column {
                                visible: win.busy
                                width: parent.width
                                spacing: 8
                                Text { text: win.pmsg + (win.pct > 0 ? "  %" + Math.round(win.pct) : ""); color: "white"; font { family: Theme.font; pixelSize: 13 } }
                                Rectangle {
                                    id: pbar
                                    width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.18); clip: true
                                    Rectangle {
                                        width: win.pct > 0 ? pbar.width * win.pct / 100 : 0
                                        height: parent.height; radius: 3; color: "white"
                                        Behavior on width { NumberAnimation { duration: 300 } }
                                    }
                                    Rectangle {
                                        visible: win.pct <= 0
                                        width: 60; height: parent.height; radius: 3; color: "white"
                                        SequentialAnimation on x { running: win.busy && win.pct <= 0; loops: Animation.Infinite
                                            NumberAnimation { from: -60; to: pbar.width; duration: 1200; easing.type: Easing.InOutQuad } }
                                    }
                                }
                            }
                        }
                    }

                    Toast { visible: win.notice !== "" && win.page === "detail"; width: Math.min(parent.width, implicitWidth) }

                    Text {
                        width: parent.width
                        text: win.det.description || win.cur.summary || (win.det.id ? "" : "Yükleniyor…")
                        color: "#C3CAD6"; wrapMode: Text.WordWrap; lineHeight: 1.35
                        font { family: Theme.font; pixelSize: 15 }
                    }

                    Row {
                        spacing: 14
                        visible: win.det.id !== undefined
                        InfoTile { label: "BOYUT"; value: win.det.size ? Fs.formatSize(win.det.size) : (win.det.flatpak_size || "—") }
                        InfoTile { label: "SÜRÜM"; value: win.det.version ? String(win.det.version).split("-")[0] : "—" }
                        InfoTile { label: "KAYNAK"; value: win.src === "apt" ? "Ubuntu (APT)" : "Flathub" }
                        InfoTile { label: "DURUM"; value: win.installed(win.det) ? "Yüklü" : "Yüklü değil" }
                    }

                    Column {
                        visible: win.det.screenshots !== undefined && win.det.screenshots.length > 0
                        width: parent.width
                        spacing: 12
                        Text { text: "Ekran görüntüleri"; color: Theme.text; font { family: Theme.font; pixelSize: 18; weight: Font.Medium } }
                        ListView {
                            width: parent.width; height: 220
                            orientation: ListView.Horizontal; spacing: 12; clip: true
                            model: win.det.screenshots || []
                            delegate: Rectangle {
                                required property string modelData
                                width: 360; height: 220; radius: 12; color: Qt.rgba(1, 1, 1, 0.04); clip: true
                                border.width: 1; border.color: Theme.stroke
                                Image { anchors.fill: parent; source: modelData; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Küçük bileşenler ---
    component SectionLabel: Text {
        leftPadding: 2
        bottomPadding: 6
        color: Theme.textDim
        font { family: Theme.font; pixelSize: 11; letterSpacing: 1.4; weight: Font.Medium }
    }
    component NavItem: Rectangle {
        id: nav
        property string icon
        property string label
        property int badge: 0
        property bool active: false
        signal clicked()
        width: parent ? parent.width : 200
        height: 44
        radius: 12
        color: active ? Qt.rgba(1, 1, 1, 0.07) : (navMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.035) : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 14
            Icon { name: nav.icon; size: 19; color: nav.active ? Theme.text : Theme.textDim }
            Text {
                Layout.fillWidth: true
                text: nav.label
                color: nav.active ? Theme.text : "#C3CAD6"
                font { family: Theme.font; pixelSize: 14; weight: nav.active ? Font.Medium : Font.Normal }
            }
            Rectangle {
                visible: nav.badge > 0
                Layout.preferredWidth: Math.max(22, bt.implicitWidth + 12); Layout.preferredHeight: 22; radius: 11
                color: Theme.accent
                Text { id: bt; anchors.centerIn: parent; text: nav.badge; color: Theme.accentInk; font { family: Theme.font; pixelSize: 11; weight: Font.DemiBold } }
            }
        }
        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: nav.clicked() }
    }
    // Uygulama simgesi: gerçek simge varsa o, yoksa renkli karo
    component AppIcon: Item {
        id: ai
        property var app: ({})
        property int size: 56
        width: size; height: size
        Rectangle {
            anchors.fill: parent
            radius: ai.size * 0.24
            visible: img.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: ai.app.c2 || "#445" }
                GradientStop { position: 1; color: ai.app.c1 || "#223" }
            }
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
            Icon { anchors.centerIn: parent; name: ai.app.lucide || "package"; size: ai.size * 0.46; color: "#FFFFFF" }
        }
        Image {
            id: img
            anchors.fill: parent
            source: ai.app.icon ? "file://" + ai.app.icon : ""
            sourceSize: Qt.size(ai.size * 2, ai.size * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
    }
    component AppCard: Rectangle {
        id: card
        property var app: ({})
        signal clicked()
        width: 276; height: 100; radius: 16
        color: cm.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
        border.width: 1; border.color: cm.containsMouse ? Theme.strokeHi : Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        scale: cm.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dFast } }
        AppIcon { id: ci; app: card.app; size: 60; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } }
        Column {
            anchors { left: ci.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 4
            Text { text: card.app.name || ""; width: parent.width; elide: Text.ElideRight; color: Theme.text; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
            Text { text: card.app.summary || ""; width: parent.width; elide: Text.ElideRight; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.clicked() }
    }
    component ListRow: Rectangle {
        id: lr
        property var app: ({})
        property bool removable: false
        signal clicked()
        width: ListView.view ? ListView.view.width : 400; height: 76; radius: 14
        color: lm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.035)
        border.width: 1; border.color: Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lr.clicked() }
        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 16 }
            spacing: 14
            AppIcon { app: lr.app; size: 48 }
            Column {
                Layout.fillWidth: true
                spacing: 3
                Text { text: lr.app.name || ""; width: parent.width; elide: Text.ElideRight; color: Theme.text; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
                Text { text: lr.app.summary || ""; width: parent.width; elide: Text.ElideRight; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
            }
            Badge { text: lr.app.source === "flatpak" ? "Flatpak" : "APT"; on: false }
            Text { visible: lr.app.installed && !lr.removable; text: "Yüklü"; color: Theme.accent; font { family: Theme.font; pixelSize: 13 } }
            GhostButton {
                visible: lr.removable
                label: "Kaldır"; icon: "trash-2"; danger: true
                onClicked: { win.openApp(lr.app, false); win.doRemove(lr.app.source === "flatpak" ? lr.app.flatpak : lr.app.pkg, lr.app.source); }
            }
        }
    }
    component PrimaryButton: Rectangle {
        id: pb
        property string label
        property string icon
        signal clicked()
        implicitWidth: pr.implicitWidth + 44; implicitHeight: 44
        width: implicitWidth; height: 44
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0; color: "#B8CCF6" }
            GradientStop { position: 1; color: "#9DB7EE" }
        }
        scale: pm.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dFast } }
        Row {
            id: pr
            anchors.centerIn: parent
            spacing: 10
            Icon { visible: pb.icon !== ""; name: pb.icon; size: 17; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pb.label; color: Theme.accentInk; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
        }
        MouseArea { id: pm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
    }
    component GhostButton: Rectangle {
        id: gb
        property string label
        property string icon
        property bool danger: false
        signal clicked()
        implicitWidth: gr.implicitWidth + 36; implicitHeight: 40
        width: implicitWidth; height: 40
        radius: 12
        color: gm.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1; border.color: gb.danger ? Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.4) : Theme.strokeHi
        Row {
            id: gr
            anchors.centerIn: parent
            spacing: 8
            Icon { visible: gb.icon !== ""; name: gb.icon; size: 16; color: gb.danger ? Theme.danger : Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: gb.label; color: gb.danger ? Theme.danger : Theme.text; font { family: Theme.font; pixelSize: 14 } }
        }
        MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gb.clicked() }
    }
    component Badge: Rectangle {
        id: bd
        property string text
        property bool on: false
        property bool check: false
        signal clicked()
        implicitWidth: bl.implicitWidth + 22; implicitHeight: 26
        width: implicitWidth; height: 26; radius: 13
        color: on ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.07)
        border.width: 1; border.color: on ? Qt.rgba(1, 1, 1, 0.5) : Theme.stroke
        Row {
            id: bl
            anchors.centerIn: parent
            spacing: 5
            Icon { visible: bd.check; name: "check"; size: 12; color: "white"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: bd.text; color: bd.on ? "white" : Theme.textDim; font { family: Theme.font; pixelSize: 12; weight: Font.Medium } }
        }
        MouseArea { anchors.fill: parent; onClicked: bd.clicked() }
    }
    component InfoTile: Rectangle {
        property string label
        property string value
        width: 190; height: 70; radius: 14
        color: Qt.rgba(1, 1, 1, 0.04); border.width: 1; border.color: Theme.stroke
        Column {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 6
            Text { text: parent.parent.label; color: Theme.textFaint; font { family: Theme.font; pixelSize: 10; letterSpacing: 1.3; weight: Font.Medium } }
            Text { text: parent.parent.value; color: Theme.text; font { family: Theme.font; pixelSize: 15 } }
        }
    }
    component Toast: Rectangle {
        implicitWidth: tt.implicitWidth + 40; implicitHeight: 42
        radius: 12
        color: win.noticeOk ? Qt.rgba(120 / 255, 200 / 255, 150 / 255, 0.16) : Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.14)
        border.width: 1; border.color: win.noticeOk ? Qt.rgba(120 / 255, 200 / 255, 150 / 255, 0.4) : Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.4)
        Text { id: tt; anchors.centerIn: parent; text: win.notice; color: win.noticeOk ? "#9BE0B4" : Theme.danger; font { family: Theme.font; pixelSize: 13 } }
    }
    component Busy: Item {
        width: 40; height: 40
        Rectangle {
            anchors.fill: parent; radius: 20; color: "transparent"
            border.width: 3; border.color: Qt.rgba(1, 1, 1, 0.1)
        }
        Item {
            anchors.fill: parent
            RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.visible }
            Rectangle { width: 8; height: 8; radius: 4; color: Theme.accent; anchors.horizontalCenter: parent.horizontalCenter; y: -1 }
        }
    }
}
