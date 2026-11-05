import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import AyazOS.UI
import AyazOS.Native

// AyazOS Galeri: zaman çizelgesi ve görüntüleyici
Window {
    id: win
    width: 1280
    height: 820
    minimumWidth: 860
    minimumHeight: 560
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Galeri"

    readonly property string helper: Qt.resolvedUrl("bin/ayaz-gallery-helper").toString().replace("file://", "")
    readonly property var months: ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

    // --- kitaplık ---
    property var items: []
    property bool loaded: false
    property bool scanning: false
    property var thumbReady: ({})
    property string folder: ""             // boş: tümü
    property string query: ""
    property real tile: 190                // istenen kutucuk boyutu

    // --- görüntüleyici ---
    property var vlist: []                 // görüntüleyicinin gezdiği liste
    property int vindex: -1
    property bool viewer: false
    property real openP: 0
    property rect fromRect: Qt.rect(0, 0, 100, 100)
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property bool infoOpen: false
    property var exif: ({})
    property int bust: 0
    property bool reloading: false
    property string toast: ""
    readonly property var curItem: vindex >= 0 && vindex < vlist.length ? vlist[vindex] : null

    function lc(s) { return (s || "").toLocaleLowerCase("tr"); }
    function dirOf(p) { return p.substring(0, p.lastIndexOf("/")); }
    function baseOf(p) { return p.substring(p.lastIndexOf("/") + 1); }
    function fmtSize(b) {
        if (b < 1024) return b + " B";
        if (b < 1048576) return (b / 1024).toFixed(0) + " KB";
        return (b / 1048576).toFixed(1) + " MB";
    }
    function fmtDate(sec) {
        const d = new Date(sec * 1000);
        const m = d.getMinutes();
        return d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear() + ", " + d.getHours() + ":" + (m < 10 ? "0" : "") + m;
    }
    function say(t) { toast = t; toastTimer.restart(); }

    // ---------- süreçler ----------
    Component { id: procC; Proc { } }
    function run(args, cb) {
        const p = procC.createObject(win);
        p.finished.connect((code, out, err) => { if (cb) cb(code, out); p.destroy(); });
        p.startWith(args);
    }

    // ---------- kitaplık ----------
    readonly property var filtered: {
        const q = lc(query);
        return items.filter(t => (!folder || dirOf(t.path) === folder) && (!q || lc(t.name).indexOf(q) >= 0));
    }
    readonly property var folders: {
        const m = {};
        items.forEach(t => { const d = dirOf(t.path); m[d] = (m[d] || 0) + 1; });
        return Object.keys(m).map(d => ({ path: d, name: baseOf(d), count: m[d] })).sort((a, b) => b.count - a.count).slice(0, 8);
    }

    function loadLib() {
        scanning = true;
        run([helper, "scan"], (code, out) => {
            win.scanning = false;
            try {
                const list = JSON.parse(out);
                const ready = {};
                const missing = [];
                list.forEach(t => { if (t.has) ready[t.path] = true; else missing.push(t.path); });
                win.thumbReady = ready;
                win.items = list;
                if (missing.length) win.makeThumbs(missing, false);
            } catch (e) { }
            win.loaded = true;
            if (win.pendingOpen) { win.openPending(); }
        });
    }

    property var doneBatch: []
    Timer {
        id: batchTimer
        interval: 250
        onTriggered: {
            const r = Object.assign({}, win.thumbReady);
            win.doneBatch.forEach(p => r[p] = true);
            win.doneBatch = [];
            win.thumbReady = r;
        }
    }
    Component {
        id: thumbProcC
        Proc {
            onLine: text => { win.doneBatch.push(text); batchTimer.start(); }
        }
    }
    function makeThumbs(paths, force) {
        const p = thumbProcC.createObject(win);
        p.finished.connect(() => { batchTimer.start(); p.destroy(); });
        const a = [helper, "thumbs", JSON.stringify(paths)];
        if (force) a.push("force");
        p.startWith(a);
    }

    // başlangıçta bir dosya verildiyse
    property string pendingFile: ""
    property bool pendingOpen: false
    function openPending() {
        pendingOpen = false;
        const f = pendingFile;
        let idx = -1;
        let list = items;
        for (let i = 0; i < list.length; i++) if (list[i].path === f) { idx = i; break; }
        if (idx >= 0 && !folder) {
            vlist = filtered; idx = vlist.findIndex(t => t.path === f);
            openViewer(idx, Qt.rect(win.width / 2 - 50, win.height / 2 - 50, 100, 100));
        } else {
            run([helper, "scan", dirOf(f)], (code, out) => {
                try {
                    win.vlist = JSON.parse(out);
                    const i = win.vlist.findIndex(t => t.path === f);
                    if (i >= 0) win.openViewer(i, Qt.rect(win.width / 2 - 50, win.height / 2 - 50, 100, 100));
                } catch (e) { }
            });
        }
    }

    Component.onCompleted: {
        if (appArgs.length > 0 && !appArgs[0].startsWith("--")) {
            let f = appArgs[0];
            if (f.startsWith("file://")) f = decodeURIComponent(f.substring(7));
            pendingFile = f;
            pendingOpen = true;
        }
        loadLib();
    }

    // ---------- görüntüleyici ----------
    function openViewer(i, rect) {
        vindex = i;
        fromRect = rect;
        zoom = 1; panX = 0; panY = 0;
        exif = ({});
        viewer = true;
        openAnim.from = 0; openAnim.to = 1; openAnim.restart();
        loadExif();
    }
    function closeViewer() {
        if (!viewer) return;
        // listedeki kutucuğa geri küçül
        zoom = 1; panX = 0; panY = 0;
        viewer = false;
        openAnim.from = openP; openAnim.to = 0; openAnim.restart();
    }
    NumberAnimation { id: openAnim; target: win; property: "openP"; duration: 260; easing.type: Easing.OutCubic }

    function go(delta) {
        const n = vindex + delta;
        if (n < 0 || n >= vlist.length) return;
        vindex = n;
        zoom = 1; panX = 0; panY = 0;
        exif = ({});
        loadExif();
    }
    function loadExif() {
        const it = curItem;
        if (!it) return;
        const path = it.path;
        run([helper, "exif", path], (code, out) => {
            try { if (win.curItem && win.curItem.path === path) win.exif = JSON.parse(out); } catch (e) { }
        });
    }
    function clampPan() {
        const lx = Math.max(0, stageBox.fitW * zoom / 2), ly = Math.max(0, stageBox.fitH * zoom / 2);
        panX = Math.max(-lx, Math.min(lx, panX));
        panY = Math.max(-ly, Math.min(ly, panY));
    }
    function setZoom(nz, cx, cy) {
        nz = Math.max(1, Math.min(12, nz));
        const k = nz / zoom;
        const dx = cx - (stageBox.cx + panX), dy = cy - (stageBox.cy + panY);
        panX = panX - dx * (k - 1);
        panY = panY - dy * (k - 1);
        zoom = nz;
        if (zoom <= 1.001) { zoom = 1; panX = 0; panY = 0; }
        clampPan();
    }

    function rotate(deg) {
        const it = curItem;
        if (!it) return;
        const path = it.path;
        run(["sh", "-c", "t=$(stat -c %Y \"$1\"); mogrify -auto-orient -rotate \"$2\" \"$1\" && touch -d \"@$t\" \"$1\"", "sh", path, String(deg)], (code) => {
            if (code !== 0) { win.say("Döndürülemedi"); return; }
            const r = Object.assign({}, win.thumbReady); delete r[path]; win.thumbReady = r;
            win.makeThumbs([path], true);
            win.bust++;
            win.reloading = true; reloadTimer.restart();
            win.say("Döndürüldü");
        });
    }
    function trashCurrent() {
        const it = curItem;
        if (!it) return;
        run(["gio", "trash", it.path], (code) => {
            if (code !== 0) { win.say("Çöpe taşınamadı"); return; }
            const rest = win.vlist.filter(t => t.path !== it.path);
            win.items = win.items.filter(t => t.path !== it.path);
            win.say("Çöp kutusuna taşındı");
            if (rest.length === 0) { win.vlist = rest; win.closeViewer(); return; }
            const ni = Math.min(win.vindex, rest.length - 1);
            win.vlist = rest;
            win.vindex = ni;
            win.zoom = 1; win.panX = 0; win.panY = 0;
            win.loadExif();
        });
    }
    function setWallpaper() {
        const it = curItem;
        if (!it) return;
        run([helper, "wallpaper", it.path], () => win.say("Duvar kağıdı olarak ayarlandı"));
    }
    function openFolder() {
        if (curItem) Proc.detached(["ayaz-files", dirOf(curItem.path)]);
    }

    Timer { id: reloadTimer; interval: 60; onTriggered: { win.reloading = false; win.loadExif(); } }
    Timer { id: toastTimer; interval: 2200; onTriggered: win.toast = "" }

    Shortcut { sequence: "Escape"; enabled: win.viewer; onActivated: win.closeViewer() }
    Shortcut { sequence: "Left"; enabled: win.viewer; onActivated: win.go(-1) }
    Shortcut { sequence: "Right"; enabled: win.viewer; onActivated: win.go(1) }
    Shortcut { sequence: "Delete"; enabled: win.viewer; onActivated: win.trashCurrent() }
    Shortcut { sequence: "I"; enabled: win.viewer; onActivated: win.infoOpen = !win.infoOpen }
    Shortcut { sequence: "R"; enabled: win.viewer; onActivated: win.rotate(90) }
    Shortcut { sequence: "Shift+R"; enabled: win.viewer; onActivated: win.rotate(-90) }
    Shortcut { sequences: ["+", "="]; enabled: win.viewer; onActivated: win.setZoom(win.zoom * 1.4, stageBox.cx, stageBox.cy) }
    Shortcut { sequence: "-"; enabled: win.viewer; onActivated: win.setZoom(win.zoom / 1.4, stageBox.cx, stageBox.cy) }
    Shortcut { sequence: "0"; enabled: win.viewer; onActivated: { win.zoom = 1; win.panX = 0; win.panY = 0; } }
    Shortcut { sequences: ["Ctrl+K", "Ctrl+F"]; enabled: !win.viewer; onActivated: search.forceActiveFocus() }

    // ================= Görünüm =================
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
                elide: Text.ElideRight
                color: nav.active ? Theme.text : "#C3CAD6"
                font { family: Theme.font; pixelSize: 14; weight: nav.active ? Font.Medium : Font.Normal }
            }
            Text { visible: nav.badge > 0; text: nav.badge; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
        }
        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: nav.clicked() }
    }
    // Viewer üst çubuğundaki yuvarlak düğme
    component VBtn: Item {
        id: vb
        property string icon
        property string tip
        property bool on: false
        property bool danger: false
        signal clicked()
        width: 40; height: 40
        Rectangle {
            anchors.fill: parent; radius: 12
            color: vbm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : (vb.on ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.dFast } }
        }
        Icon {
            anchors.centerIn: parent; name: vb.icon; size: 19
            color: vb.danger && vbm.containsMouse ? Theme.danger : (vb.on ? Theme.accent : Theme.text)
            scale: vbm.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: Theme.dFast } }
        }
        MouseArea { id: vbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: vb.clicked() }
    }

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
                    Icon { name: "images"; size: 22 }
                    Text { text: "Galeri"; color: Theme.text; font { family: Theme.font; pixelSize: 17; weight: Font.DemiBold } }
                }
                Item { Layout.fillWidth: true }
                // kutucuk boyutu
                Row {
                    spacing: 10
                    Layout.rightMargin: 16
                    Icon { name: "layout-grid"; size: 15; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    Item {
                        width: 110; height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.14)
                            Rectangle { width: parent.width * (win.tile - 120) / 180; height: parent.height; radius: 2; color: Theme.accent }
                            Rectangle {
                                width: 12; height: 12; radius: 6; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * (win.tile - 120) / 180 - 6
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function set(mx) { win.tile = 120 + 180 * Math.max(0, Math.min(1, mx / width)); }
                            onPressed: m => set(m.x)
                            onPositionChanged: m => { if (pressed) set(m.x); }
                        }
                    }
                    Icon { name: "image"; size: 19; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    Layout.preferredWidth: 240; Layout.preferredHeight: 40
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: search.activeFocus ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.45) : Theme.stroke
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                        spacing: 8
                        Icon { name: "search"; size: 16; color: Theme.textDim }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            color: Theme.text
                            clip: true
                            font { family: Theme.font; pixelSize: 13 }
                            onTextEdited: win.query = text
                            Keys.onEscapePressed: { text = ""; win.query = ""; focus = false; }
                            Text {
                                visible: !search.text
                                text: "Dosya adı ara"
                                color: Theme.textFaint
                                font: search.font
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text { visible: !search.text; text: "Ctrl K"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11 } }
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
                SectionLabel { text: "KİTAPLIK" }
                NavItem { icon: "images"; label: "Tüm fotoğraflar"; badge: win.items.length; active: win.folder === ""; onClicked: win.folder = "" }
                Item { width: 1; height: 8 }
                Rectangle { width: parent.width; height: 1; color: Theme.stroke; opacity: 0.8 }
                Item { width: 1; height: 6 }
                SectionLabel { text: "KLASÖRLER" }
                Repeater {
                    model: win.folders
                    NavItem {
                        required property var modelData
                        icon: "folder"; label: modelData.name; badge: modelData.count
                        active: win.folder === modelData.path
                        onClicked: win.folder = modelData.path
                    }
                }
            }
            Row {
                anchors { left: parent.left; bottom: parent.bottom; margins: 28; bottomMargin: 22 }
                spacing: 8
                Icon {
                    name: "refresh-cw"; size: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter
                    RotationAnimation on rotation { running: win.scanning; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
                }
                Text {
                    text: win.scanning ? "Taranıyor…" : "Kitaplığı yenile"
                    color: Theme.textDim; font { family: Theme.font; pixelSize: 12 }
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; onClicked: if (!win.scanning) win.loadLib() }
                }
            }
        }

        // --- Zaman çizelgesi ---
        Item {
            id: content
            anchors { left: sidebar.right; right: parent.right; top: header.bottom; bottom: parent.bottom }

            Column {
                id: pageHead
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 34; rightMargin: 32; topMargin: 32 }
                spacing: 6
                Text {
                    text: win.folder ? win.baseOf(win.folder) : "Fotoğraflar"
                    color: Theme.text; font { family: Theme.font; pixelSize: 28 }
                }
                Text {
                    text: win.query ? "“" + win.query + "” için " + win.filtered.length + " sonuç" : win.filtered.length + " fotoğraf"
                    color: Theme.textDim; font { family: Theme.font; pixelSize: 13 }
                }
            }

            readonly property int gap: 6
            readonly property real gridW: width - 44
            readonly property int cols: Math.max(2, Math.round((gridW + gap) / (win.tile + gap)))
            readonly property real cell: (gridW - (cols - 1) * gap) / cols

            // satır modeli: ay başlıkları + kutucuk satırları
            readonly property var rows: {
                const list = win.filtered, out = [], cols = content.cols;
                let curKey = "", bucket = [], hdr = null;
                function flush() {
                    if (!hdr) return;
                    hdr.count = bucket.length;
                    for (let i = 0; i < bucket.length; i += cols) out.push({ h: false, items: bucket.slice(i, i + cols), start: bucket[i].idx });
                }
                for (let i = 0; i < list.length; i++) {
                    const d = new Date(list[i].date * 1000);
                    const key = d.getFullYear() * 12 + d.getMonth();
                    if (key !== curKey) {
                        flush();
                        curKey = key; bucket = [];
                        hdr = { h: true, label: win.months[d.getMonth()] + " " + d.getFullYear(), count: 0 };
                        out.push(hdr);
                    }
                    bucket.push({ t: list[i], idx: i });
                }
                flush();
                return out;
            }

            ListView {
                id: tl
                anchors { fill: parent; topMargin: 100; leftMargin: 22; rightMargin: 22 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: content.rows
                bottomMargin: 24
                cacheBuffer: 600
                delegate: Item {
                    id: rowItem
                    required property var modelData
                    width: tl.width
                    height: modelData.h ? 62 : content.cell + content.gap
                    Row {
                        visible: rowItem.modelData.h
                        anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
                        spacing: 12
                        Text { text: rowItem.modelData.label || ""; color: Theme.text; font { family: Theme.font; pixelSize: 19; weight: Font.Medium } anchors.verticalCenter: parent.verticalCenter }
                        Text { text: rowItem.modelData.count || 0; color: Theme.textFaint; font { family: Theme.font; pixelSize: 13 } anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        visible: !rowItem.modelData.h
                        spacing: content.gap
                        Repeater {
                            model: rowItem.modelData.h ? [] : rowItem.modelData.items
                            Rectangle {
                                id: tileR
                                required property var modelData
                                readonly property bool ready: win.thumbReady[modelData.t.path] === true
                                width: content.cell; height: content.cell
                                radius: 10
                                clip: true
                                color: "#141A26"
                                Image {
                                    id: timg
                                    anchors.fill: parent
                                    source: tileR.ready ? "file://" + tileR.modelData.t.thumb : ""
                                    sourceSize: Qt.size(320, 320)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: win.bust === 0
                                    autoTransform: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    scale: tm.containsMouse ? 1.06 : 1
                                    Behavior on opacity { NumberAnimation { duration: Theme.dNormal } }
                                    Behavior on scale { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
                                }
                                Icon { visible: timg.status !== Image.Ready; anchors.centerIn: parent; name: "image"; size: 26; color: Theme.textFaint }
                                Rectangle {
                                    anchors.fill: parent; radius: parent.radius; color: "transparent"
                                    border.width: 1; border.color: tm.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                                }
                                MouseArea {
                                    id: tm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const p = tileR.mapToItem(frame, 0, 0);
                                        win.vlist = win.filtered;
                                        win.openViewer(tileR.modelData.idx, Qt.rect(p.x, p.y, tileR.width, tileR.height));
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                visible: win.loaded && win.filtered.length === 0
                anchors.centerIn: parent
                spacing: 14
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "images"; size: 54; color: Theme.textFaint }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.scanning ? "Taranıyor…" : (win.query ? "Sonuç bulunamadı" : "Henüz fotoğraf yok"); color: Theme.text; font { family: Theme.font; pixelSize: 18 } }
                Text { visible: !win.query; anchors.horizontalCenter: parent.horizontalCenter; text: "Fotoğrafları Resimler klasörüne koy, burada görünsünler."; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } }
            }
        }

        // ================= Görüntüleyici =================
        Item {
            id: viewerLayer
            anchors.fill: parent
            visible: win.openP > 0.001
            readonly property real panelW: win.infoOpen ? 330 : 0

            Rectangle { anchors.fill: parent; color: "#07090E"; opacity: win.openP }
            Item { id: vMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: frame.radius; color: "#000" } }
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: vMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
            MouseArea { anchors.fill: parent; enabled: win.viewer }   // alttakini engelle

            // resim kutusu
            Item {
                id: stage
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: viewerLayer.panelW }
                Behavior on anchors.rightMargin { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
                clip: true

                Item {
                    id: stageBox
                    anchors.fill: parent
                    readonly property real asp: {
                        const w = thumbImg.implicitWidth > 0 ? thumbImg.implicitWidth : (pic.implicitWidth > 0 ? pic.implicitWidth : 4);
                        const h = thumbImg.implicitHeight > 0 ? thumbImg.implicitHeight : (pic.implicitHeight > 0 ? pic.implicitHeight : 3);
                        return w / h;
                    }
                    readonly property real availW: Math.max(100, stage.width - 150)
                    readonly property real availH: Math.max(100, stage.height - 190)
                    readonly property real fitW: Math.min(availW, availH * asp)
                    readonly property real fitH: fitW / asp
                    readonly property real cx: stage.width / 2
                    readonly property real cy: stage.height / 2 + 5

                    // dönüşüm: kutucuktan tam boyuta
                    Item {
                        id: box
                        readonly property real p: win.openP
                        readonly property point fp: stage.mapFromItem(frame, win.fromRect.x, win.fromRect.y)
                        x: fp.x + (stageBox.cx - stageBox.fitW / 2 - fp.x) * p + win.panX
                        y: fp.y + (stageBox.cy - stageBox.fitH / 2 - fp.y) * p + win.panY
                        width: win.fromRect.width + (stageBox.fitW - win.fromRect.width) * p
                        height: win.fromRect.height + (stageBox.fitH - win.fromRect.height) * p
                        scale: win.zoom
                        transformOrigin: Item.Center

                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: win.curItem && !win.reloading ? "file://" + win.curItem.thumb : ""
                            fillMode: Image.Stretch
                            autoTransform: true
                            cache: win.bust === 0
                            asynchronous: false
                            visible: pic.status !== Image.Ready
                        }
                        Image {
                            id: pic
                            anchors.fill: parent
                            source: win.curItem && !win.reloading ? "file://" + win.curItem.path : ""
                            sourceSize: Qt.size(4096, 4096)
                            fillMode: Image.Stretch
                            autoTransform: true
                            asynchronous: true
                            cache: false
                            smooth: true
                            mipmap: true
                        }
                    }
                }

                // etkileşim
                PinchHandler {
                    id: pinch
                    target: null
                    property real startZoom: 1
                    onActiveChanged: if (active) startZoom = win.zoom
                    onActiveScaleChanged: if (active) win.setZoom(startZoom * activeScale, centroid.position.x, centroid.position.y)
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: ev => win.setZoom(win.zoom * Math.pow(1.0018, ev.angleDelta.y), point.position.x, point.position.y)
                }
                DragHandler {
                    id: dragH
                    target: null
                    enabled: win.zoom > 1
                    property real sx: 0
                    property real sy: 0
                    onActiveChanged: if (active) { sx = win.panX; sy = win.panY; }
                    onTranslationChanged: if (active) { win.panX = sx + translation.x; win.panY = sy + translation.y; win.clampPan(); }
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onDoubleTapped: tp => { if (win.zoom > 1) { win.zoom = 1; win.panX = 0; win.panY = 0; } else win.setZoom(2.5, tp.position.x, tp.position.y); }
                }
            }

            // üst çubuk
            Rectangle {
                id: vtop
                z: 5
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 76
                opacity: win.openP
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 1; color: "transparent" }
                }
                MouseArea { anchors.fill: parent; onPressed: win.startSystemMove() }
                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                    spacing: 6
                    VBtn { icon: "arrow-left"; onClicked: win.closeViewer() }
                    Column {
                        Layout.leftMargin: 10
                        spacing: 3
                        Text { text: win.curItem ? win.curItem.name : ""; color: "#fff"; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
                        Text { text: win.curItem ? win.fmtDate(win.curItem.date) : ""; color: Qt.rgba(1, 1, 1, 0.6); font { family: Theme.font; pixelSize: 12 } }
                    }
                    Item { Layout.fillWidth: true }
                    VBtn { icon: "rotate-ccw"; onClicked: win.rotate(-90) }
                    VBtn { icon: "rotate-cw"; onClicked: win.rotate(90) }
                    VBtn { icon: "monitor-up"; onClicked: win.setWallpaper() }
                    VBtn { icon: "folder-open"; onClicked: win.openFolder() }
                    VBtn { icon: "info"; on: win.infoOpen; onClicked: win.infoOpen = !win.infoOpen }
                    VBtn { icon: "trash-2"; danger: true; onClicked: win.trashCurrent() }
                    Item { Layout.preferredWidth: 8 }
                    VBtn { icon: "x"; onClicked: win.close() }
                }
            }

            // gezinme okları
            Rectangle {
                visible: win.vindex > 0
                anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                width: 48; height: 48; radius: 24
                color: lm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                opacity: win.openP
                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                Icon { anchors.centerIn: parent; name: "chevron-left"; size: 24 }
                MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(-1) }
            }
            Rectangle {
                visible: win.vindex < win.vlist.length - 1
                anchors { right: parent.right; rightMargin: 22 + viewerLayer.panelW; verticalCenter: parent.verticalCenter }
                Behavior on anchors.rightMargin { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
                width: 48; height: 48; radius: 24
                color: rmo.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                opacity: win.openP
                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                Icon { anchors.centerIn: parent; name: "chevron-right"; size: 24 }
                MouseArea { id: rmo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(1) }
            }

            // alt: sayaç + yakınlaştırma
            Rectangle {
                anchors { horizontalCenter: stage.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
                width: botRow.implicitWidth + 28; height: 46; radius: 23
                color: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.85)
                border.width: 1; border.color: Theme.stroke
                opacity: win.openP
                Row {
                    id: botRow
                    anchors.centerIn: parent
                    spacing: 4
                    VBtn { icon: "zoom-out"; width: 36; height: 36; onClicked: win.setZoom(win.zoom / 1.4, stageBox.cx, stageBox.cy); anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        width: 52; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(win.zoom * 100) + "%"; color: Theme.text; font { family: Theme.font; pixelSize: 13 }
                        MouseArea { anchors.fill: parent; onClicked: { win.zoom = 1; win.panX = 0; win.panY = 0; } }
                    }
                    VBtn { icon: "zoom-in"; width: 36; height: 36; onClicked: win.setZoom(win.zoom * 1.4, stageBox.cx, stageBox.cy); anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 1; height: 20; color: Theme.stroke; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        width: 70; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
                        text: (win.vindex + 1) + " / " + win.vlist.length; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 }
                    }
                }
            }

            // bilgi paneli
            Rectangle {
                id: infoPanel
                width: 330
                anchors { top: parent.top; bottom: parent.bottom }
                x: win.infoOpen ? parent.width - width : parent.width
                Behavior on x { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
                color: Qt.rgba(14 / 255, 19 / 255, 28 / 255, 0.97)
                Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.stroke }
                visible: x < parent.width
                MouseArea { anchors.fill: parent }
                Column {
                    anchors { fill: parent; margins: 28; topMargin: 90 }
                    spacing: 20
                    Text { text: "Bilgi"; color: Theme.text; font { family: Theme.font; pixelSize: 20 } }
                    Repeater {
                        model: {
                            const it = win.curItem;
                            if (!it) return [];
                            const e = win.exif;
                            const w = e.ImageWidth || pic.sourceSize.width, h = e.ImageHeight || pic.sourceSize.height;
                            const rows = [
                                { k: "Ad", v: it.name },
                                { k: "Boyut", v: win.fmtSize(it.size) },
                                { k: "Çözünürlük", v: w && h ? w + " × " + h + " (" + (w * h / 1e6).toFixed(1) + " MP)" : "" },
                                { k: "Tarih", v: win.fmtDate(it.date) },
                                { k: "Konum", v: win.dirOf(it.path) }
                            ];
                            if (e.Make || e.Model) rows.push({ k: "Kamera", v: ((e.Make || "") + " " + (e.Model || "")).trim() });
                            if (e.LensModel) rows.push({ k: "Mercek", v: e.LensModel });
                            const ex = [];
                            if (e.FNumber) ex.push("f/" + e.FNumber);
                            if (e.ExposureTime) ex.push(e.ExposureTime + " sn");
                            if (e.ISO) ex.push("ISO " + e.ISO);
                            if (e.FocalLength) ex.push(e.FocalLength);
                            if (ex.length) rows.push({ k: "Çekim", v: ex.join("  ·  ") });
                            return rows.filter(r => r.v);
                        }
                        Column {
                            required property var modelData
                            width: infoPanel.width - 56
                            spacing: 4
                            Text { text: modelData.k.toUpperCase(); color: Theme.textFaint; font { family: Theme.font; pixelSize: 10; letterSpacing: 1.3; weight: Font.Medium } }
                            Text { width: parent.width; text: modelData.v; wrapMode: Text.WrapAnywhere; color: Theme.text; font { family: Theme.font; pixelSize: 13 } }
                        }
                    }
                }
            }
        }

        // bildirim
        Rectangle {
            visible: win.toast !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 96 }
            width: toastText.implicitWidth + 40; height: 44; radius: 22
            color: "#1B2434"; border.width: 1; border.color: Theme.strokeHi
            Text { id: toastText; anchors.centerIn: parent; text: win.toast; color: Theme.text; font { family: Theme.font; pixelSize: 14 } }
        }
    }
}
