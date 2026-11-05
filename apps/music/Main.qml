import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import AyazOS.UI
import AyazOS.Native

// AyazOS Müzik: mpv (IPC + MPRIS) üzerinde çalışan kitaplık ve çalar
Window {
    id: win
    width: 1280
    height: 820
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Müzik"

    readonly property string helper: Qt.resolvedUrl("bin/ayaz-music-helper").toString().replace("file://", "")

    // --- kitaplık ---
    property var tracks: []
    property var byPath: ({})
    property var albums: []
    property var artists: []
    property var playlists: []
    property bool scanning: false
    property bool loaded: false

    // --- gezinme ---
    property string view: "songs"          // songs | albums | artists | playlists | detail
    property var detail: null               // {kind, title, subtitle, cover, tracks, plIndex}
    property var prevView: []
    property string query: ""
    property bool full: false

    // --- çalma durumu ---
    property bool connected: false
    property bool paused: true
    property bool idle: true
    property real pos: 0
    property real dur: 0
    property real volume: 80
    property bool muted: false
    property string curPath: ""
    property string mediaTitle: ""
    property var meta: ({})
    property bool shuffle: false
    property int repeat: 0                  // 0 kapalı, 1 liste, 2 tek parça
    property var queue: []
    property int queueIdx: -1
    readonly property bool playing: !idle && !paused

    readonly property var cur: {
        if (!curPath) return null;
        const t = byPath[curPath];
        if (t) return t;
        let artist = "", album = "";
        for (const k in meta) {
            const l = k.toLowerCase();
            if (l === "artist") artist = meta[k];
            if (l === "album") album = meta[k];
        }
        return { path: curPath, title: mediaTitle || curPath.split("/").pop(), artist: artist, album: album, cover: "", duration: dur };
    }

    function fmt(s) {
        s = Math.max(0, Math.floor(s || 0));
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    function coverUrl(t) { return t && t.cover ? "file://" + t.cover : ""; }
    function lc(s) { return (s || "").toLocaleLowerCase("tr"); }

    // ---------- yardımcı süreç ----------
    Component {
        id: procC
        Proc { }
    }
    function run(args, cb) {
        const p = procC.createObject(win);
        p.finished.connect((code, out, err) => { if (cb) cb(code, out); p.destroy(); });
        p.startWith(args);
    }
    function ctl(arr) { run([helper, "ctl", JSON.stringify(arr)]); }

    Proc {
        id: watcher
        onLine: text => {
            let d;
            try { d = JSON.parse(text); } catch (e) { return; }
            switch (d.p) {
            case "connected": win.connected = d.v; break;
            case "pause": win.paused = !!d.v; break;
            case "idle-active": win.idle = !!d.v; break;
            case "time-pos": if (!seekBar.dragging) win.pos = d.v || 0; break;
            case "duration": win.dur = d.v || 0; break;
            case "volume": if (!volBar.dragging) win.volume = d.v === null ? 0 : d.v; break;
            case "mute": win.muted = !!d.v; break;
            case "path": if (d.v) win.curPath = d.v; break;
            case "media-title": win.mediaTitle = d.v || ""; break;
            case "metadata": win.meta = d.v || {}; break;
            case "playlist-pos": win.queueIdx = d.v === null ? -1 : d.v; break;
            case "loop-file": win.loopFile = d.v; break;
            case "loop-playlist": win.loopList = d.v; break;
            }
        }
    }
    property var loopFile: false
    property var loopList: false
    function on(v) { return v !== false && v !== "no" && v !== null && v !== undefined; }
    onLoopFileChanged: repeat = on(loopFile) ? 2 : (on(loopList) ? 1 : 0)
    onLoopListChanged: repeat = on(loopFile) ? 2 : (on(loopList) ? 1 : 0)

    // ---------- kitaplık ----------
    function setLib(data) {
        const list = data.tracks || [];
        const bp = {}, am = {}, rm = {};
        list.forEach(t => {
            bp[t.path] = t;
            const ak = t.albumArtist + "|" + t.album;
            if (!am[ak]) am[ak] = { key: ak, title: t.album, artist: t.albumArtist, cover: t.cover, year: t.year, tracks: [] };
            am[ak].tracks.push(t);
            if (!am[ak].cover && t.cover) am[ak].cover = t.cover;
            if (!rm[t.artist]) rm[t.artist] = { name: t.artist, cover: t.cover, tracks: [], albums: {} };
            rm[t.artist].tracks.push(t);
            rm[t.artist].albums[t.album] = 1;
            if (!rm[t.artist].cover && t.cover) rm[t.artist].cover = t.cover;
        });
        const al = Object.values(am);
        al.forEach(a => a.tracks.sort((x, y) => (x.disc - y.disc) || (x.track - y.track) || x.title.localeCompare(y.title, "tr")));
        al.sort((x, y) => x.title.localeCompare(y.title, "tr"));
        const ar = Object.values(rm);
        ar.forEach(a => { a.count = Object.keys(a.albums).length; a.tracks.sort((x, y) => x.album.localeCompare(y.album, "tr") || (x.track - y.track)); });
        ar.sort((x, y) => x.name.localeCompare(y.name, "tr"));
        list.sort((x, y) => x.title.localeCompare(y.title, "tr"));
        byPath = bp; albums = al; artists = ar; tracks = list;
        playlists = data.playlists || [];
        loaded = true;
    }
    function reload(thenScan) {
        run([helper, "load"], (code, out) => {
            try { win.setLib(JSON.parse(out)); } catch (e) { win.loaded = true; }
            if (thenScan) win.rescan();
        });
    }
    function rescan() {
        if (scanning) return;
        scanning = true;
        run([helper, "scan"], () => { win.scanning = false; win.reload(false); });
    }
    function savePlaylists() {
        run([helper, "playlists", JSON.stringify(playlists)]);
    }

    Component.onCompleted: {
        watcher.startWith([helper, "watch"]);
        reload(true);
        for (const a of appArgs) {
            if (a === "--albums" || a === "--artists" || a === "--playlists") nav(a.slice(2));
            else if (a === "--full") full = true;
            else if (a === "--album" || a === "--artist" || a === "--playlist") startDetail = a.slice(2);
            else if (Fs.exists(a)) playFile(a);
        }
    }
    property string startDetail: ""
    onLoadedChanged: {
        if (!loaded || !startDetail) return;
        if (startDetail === "album" && albums.length) openAlbum(albums[0]);
        else if (startDetail === "artist" && artists.length) openArtist(artists[0]);
        else if (startDetail === "playlist" && playlists.length) openPlaylist(0);
        startDetail = "";
    }
    function playFile(p) { run([helper, "play", JSON.stringify([p]), "0"]); }

    // ---------- çalma ----------
    function shuffled(list, first) {
        const a = list.slice();
        for (let i = a.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [a[i], a[j]] = [a[j], a[i]];
        }
        if (first >= 0) {
            const f = list[first];
            const k = a.indexOf(f);
            a.splice(k, 1);
            a.unshift(f);
        }
        return a;
    }
    function playList(list, index, forceShuffle) {
        if (!list || list.length === 0) return;
        let q = list;
        let i = index < 0 ? 0 : index;
        if (forceShuffle || (shuffle && index < 0)) { q = shuffled(list, index); i = 0; }
        else if (shuffle) { q = shuffled(list, index); i = 0; }
        queue = q;
        run([helper, "play", JSON.stringify(q.map(t => t.path)), String(i)]);
    }
    function togglePause() {
        if (idle && queue.length === 0 && tracks.length > 0) { playList(tracks, -1); return; }
        ctl(["cycle", "pause"]);
    }
    function next() { ctl(["playlist-next"]); }
    function prev() { if (pos > 4) ctl(["seek", 0, "absolute"]); else ctl(["playlist-prev"]); }
    function cycleRepeat() {
        const n = (repeat + 1) % 3;
        ctl(["set_property", "loop-file", n === 2 ? "inf" : "no"]);
        ctl(["set_property", "loop-playlist", n === 1 ? "inf" : "no"]);
    }
    function setVolume(v) { ctl(["set_property", "volume", Math.round(v)]); }
    function seekTo(s) { ctl(["seek", s, "absolute"]); }

    function openDetail(d) {
        prevView = prevView.concat([{ view: view, detail: detail }]);
        detail = d;
        view = "detail";
    }
    function goBack() {
        if (prevView.length === 0) { view = "albums"; return; }
        const p = prevView[prevView.length - 1];
        prevView = prevView.slice(0, -1);
        view = p.view; detail = p.detail;
    }
    function nav(v) { view = v; prevView = []; detail = null; }
    function openAlbum(a) { openDetail({ kind: "album", title: a.title, subtitle: a.artist + (a.year ? " · " + a.year : ""), cover: a.cover, tracks: a.tracks }); }
    function openArtist(a) { openDetail({ kind: "artist", title: a.name, subtitle: a.count + " albüm · " + a.tracks.length + " şarkı", cover: a.cover, tracks: a.tracks }); }
    function plTracks(pl) { return pl.paths.map(p => byPath[p]).filter(t => t); }
    function openPlaylist(i) {
        const pl = playlists[i];
        const ts = plTracks(pl);
        openDetail({ kind: "playlist", plIndex: i, title: pl.name, subtitle: ts.length + " şarkı", cover: ts.length ? ts[0].cover : "", tracks: ts });
    }
    function refreshDetail() {
        if (view === "detail" && detail && detail.kind === "playlist") {
            if (detail.plIndex >= playlists.length) { goBack(); return; }
            const pl = playlists[detail.plIndex], ts = plTracks(pl);
            detail = { kind: "playlist", plIndex: detail.plIndex, title: pl.name, subtitle: ts.length + " şarkı", cover: ts.length ? ts[0].cover : "", tracks: ts };
        }
    }
    function addToPlaylist(i, path) {
        const l = playlists.slice();
        const pl = { name: l[i].name, paths: l[i].paths.slice() };
        if (pl.paths.indexOf(path) < 0) pl.paths.push(path);
        l[i] = pl; playlists = l; savePlaylists(); refreshDetail();
    }
    function removeFromPlaylist(i, path) {
        const l = playlists.slice();
        l[i] = { name: l[i].name, paths: l[i].paths.filter(p => p !== path) };
        playlists = l; savePlaylists(); refreshDetail();
    }
    function createPlaylist(name, firstPath) {
        name = name.trim();
        if (!name) return;
        playlists = playlists.concat([{ name: name, paths: firstPath ? [firstPath] : [] }]);
        savePlaylists();
    }
    function deletePlaylist(i) {
        const l = playlists.slice(); l.splice(i, 1); playlists = l; savePlaylists();
        if (view === "detail") goBack();
    }

    function matches(t) {
        if (!query) return true;
        const q = lc(query);
        return lc(t.title).indexOf(q) >= 0 || lc(t.artist).indexOf(q) >= 0 || lc(t.album).indexOf(q) >= 0;
    }
    readonly property var shownTracks: query ? tracks.filter(matches) : tracks
    readonly property var shownAlbums: query ? albums.filter(a => lc(a.title).indexOf(lc(query)) >= 0 || lc(a.artist).indexOf(lc(query)) >= 0) : albums
    readonly property var shownArtists: query ? artists.filter(a => lc(a.name).indexOf(lc(query)) >= 0) : artists

    Shortcut { sequence: "Space"; enabled: !search.activeFocus && !nameInput.activeFocus; onActivated: win.togglePause() }
    Shortcut { sequence: "Ctrl+Right"; onActivated: win.next() }
    Shortcut { sequence: "Ctrl+Left"; onActivated: win.prev() }
    Shortcut { sequences: ["Ctrl+K", "Ctrl+F"]; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Escape"; enabled: win.full; onActivated: win.full = false }

    // ---------- menü durumu ----------
    property var menuTrack: null
    property real menuX: 0
    property real menuY: 0
    property bool menuOpen: false
    property bool nameOpen: false
    property string namePath: ""
    function openAddMenu(t, item) {
        const p = item.mapToItem(frame, 0, item.height + 6);
        menuTrack = t;
        menuX = Math.min(p.x - 200, frame.width - 280);
        menuY = Math.min(p.y, frame.height - 340);
        menuOpen = true;
    }

    // ================= Görünüm =================
    component CoverArt: Rectangle {
        id: ca
        property string source
        property string seed: ""
        property bool round: false
        property int ico: Math.max(18, width * 0.34)
        radius: round ? width / 2 : Math.max(8, Math.min(16, width * 0.07))
        clip: true
        readonly property int hue: {
            let h = 0;
            for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) % 360;
            return h;
        }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.hsla(ca.hue / 360, 0.45, 0.32, 1) }
            GradientStop { position: 1; color: Qt.hsla(((ca.hue + 40) % 360) / 360, 0.5, 0.14, 1) }
        }
        Icon { anchors.centerIn: parent; name: "music"; size: ca.ico; color: Qt.rgba(1, 1, 1, 0.55); visible: img.status !== Image.Ready }
        Image {
            id: img
            anchors.fill: parent
            source: ca.source
            sourceSize: Qt.size(Math.max(120, ca.width * 2), Math.max(120, ca.height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dNormal } }
        }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08) }
    }

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

    // Tıklanabilir/sürüklenebilir ilerleme çubuğu
    component Bar: Item {
        id: bar
        property real value: 0          // 0..1
        property bool dragging: false
        property real dragValue: 0
        property int thick: 4
        property bool showHandle: true
        signal committed(real v)
        signal changing(real v)
        implicitHeight: 20
        readonly property real shown: dragging ? dragValue : value
        Rectangle {
            id: track
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: barMouse.containsMouse || bar.dragging ? bar.thick + 2 : bar.thick
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.14)
            Behavior on height { NumberAnimation { duration: Theme.dFast } }
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, bar.shown))
                height: parent.height; radius: height / 2
                color: Theme.accent
            }
            Rectangle {
                visible: bar.showHandle
                width: 12; height: 12; radius: 6; color: "#fff"
                x: parent.width * Math.max(0, Math.min(1, bar.shown)) - 6
                anchors.verticalCenter: parent.verticalCenter
                opacity: barMouse.containsMouse || bar.dragging ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dFast } }
            }
        }
        MouseArea {
            id: barMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function val(mx) { return Math.max(0, Math.min(1, mx / width)); }
            onPressed: m => { bar.dragging = true; bar.dragValue = val(m.x); bar.changing(bar.dragValue); }
            onPositionChanged: m => { if (pressed) { bar.dragValue = val(m.x); bar.changing(bar.dragValue); } }
            onReleased: m => { bar.dragValue = val(m.x); bar.dragging = false; bar.committed(bar.dragValue); }
        }
    }

    component Ctl: Item {
        id: ctl
        property string icon
        property int size: 40
        property int iconSize: 20
        property bool on: false
        property bool primary: false
        signal clicked()
        width: size; height: size
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: ctl.primary
            gradient: Gradient {
                GradientStop { position: 0; color: "#C6D6F8" }
                GradientStop { position: 1; color: "#9DB7EE" }
            }
        }
        Rectangle {
            anchors.fill: parent; radius: width / 2
            visible: !ctl.primary
            color: cm.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        }
        Icon {
            anchors.centerIn: parent
            name: ctl.icon
            size: ctl.iconSize
            color: ctl.primary ? Theme.accentInk : (ctl.on ? Theme.accent : Theme.text)
            scale: cm.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: Theme.dFast } }
        }
        Rectangle {
            visible: ctl.on && !ctl.primary
            width: 4; height: 4; radius: 2; color: Theme.accent
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctl.clicked() }
    }

    component PillButton: Rectangle {
        id: pb
        property string icon
        property string label
        property bool primary: true
        signal clicked()
        implicitWidth: pbRow.implicitWidth + 40
        implicitHeight: 44
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0; color: pb.primary ? "#B8CCF6" : Qt.rgba(1, 1, 1, pbm.containsMouse ? 0.10 : 0.06) }
            GradientStop { position: 1; color: pb.primary ? "#9DB7EE" : Qt.rgba(1, 1, 1, pbm.containsMouse ? 0.10 : 0.06) }
        }
        border.width: primary ? 0 : 1
        border.color: Theme.stroke
        scale: pbm.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dFast } }
        Row {
            id: pbRow
            anchors.centerIn: parent
            spacing: 10
            Icon { name: pb.icon; size: 17; color: pb.primary ? Theme.accentInk : Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pb.label; color: pb.primary ? Theme.accentInk : Theme.text; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
        }
        MouseArea { id: pbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
    }

    // Şarkı listesi (başlık bileşeni isteğe bağlı)
    component SongList: ListView {
        id: sl
        property var list: []
        property bool inPlaylist: false
        property int plIndex: -1
        property bool numbered: false
        model: list
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        bottomMargin: 20
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool isCur: win.curPath === modelData.path
            width: ListView.view.width - 0
            height: 56
            radius: 12
            color: isCur ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.10) : (rm.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.dFast } }
            MouseArea {
                id: rm
                anchors.fill: parent
                hoverEnabled: true
                onClicked: win.playList(sl.list, row.index)
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 14
                Item {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                    Text {
                        visible: !row.isCur && !rm.containsMouse
                        anchors.centerIn: parent
                        text: sl.numbered ? (modelData.track > 0 ? modelData.track : row.index + 1) : row.index + 1
                        color: Theme.textFaint; font { family: Theme.font; pixelSize: 13 }
                    }
                    Icon { visible: !row.isCur && rm.containsMouse; anchors.centerIn: parent; name: "play"; size: 16 }
                    Icon { visible: row.isCur; anchors.centerIn: parent; name: win.playing ? "audio-lines" : "pause"; size: 17; color: Theme.accent }
                }
                CoverArt { Layout.preferredWidth: 40; Layout.preferredHeight: 40; source: win.coverUrl(modelData); seed: modelData.album; ico: 16 }
                Column {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 200
                    spacing: 3
                    Text {
                        width: parent.width; elide: Text.ElideRight; text: modelData.title
                        color: row.isCur ? Theme.accent : Theme.text
                        font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
                    }
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.artist; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 160
                    visible: win.width > 1000
                    elide: Text.ElideRight; text: modelData.album; color: Theme.textDim
                    font { family: Theme.font; pixelSize: 13 }
                }
                IconButton {
                    id: addBtn
                    visible: rm.containsMouse || (win.menuOpen && win.menuTrack === modelData)
                    icon: sl.inPlaylist ? "x" : "list-plus"; size: 32; iconSize: 17
                    onClicked: sl.inPlaylist ? win.removeFromPlaylist(sl.plIndex, modelData.path) : win.openAddMenu(modelData, addBtn)
                }
                Text {
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: win.fmt(modelData.duration); color: Theme.textDim
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
        }
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
                    Icon { name: "music"; size: 22 }
                    Text { text: "Müzik"; color: Theme.text; font { family: Theme.font; pixelSize: 17; weight: Font.DemiBold } }
                }
                IconButton {
                    icon: "chevron-left"; size: 32
                    opacity: win.view === "detail" ? 1 : 0.35
                    onClicked: win.goBack()
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 280; Layout.preferredHeight: 40
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
                            onTextEdited: {
                                win.query = text;
                                if (text && (win.view === "detail" || win.view === "playlists")) win.nav("songs");
                            }
                            Keys.onEscapePressed: { text = ""; win.query = ""; focus = false; }
                            Text {
                                visible: !search.text
                                text: "Şarkı, sanatçı, albüm ara"
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
            anchors { left: parent.left; top: header.bottom; bottom: nowBar.top }
            width: 236
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.stroke }
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 28 }
                spacing: 4
                SectionLabel { text: "KİTAPLIK" }
                NavItem { icon: "music"; label: "Şarkılar"; badge: win.tracks.length; active: win.view === "songs"; onClicked: win.nav("songs") }
                NavItem { icon: "disc-3"; label: "Albümler"; badge: win.albums.length; active: win.view === "albums" || (win.view === "detail" && win.detail && win.detail.kind === "album"); onClicked: win.nav("albums") }
                NavItem { icon: "mic-vocal"; label: "Sanatçılar"; badge: win.artists.length; active: win.view === "artists" || (win.view === "detail" && win.detail && win.detail.kind === "artist"); onClicked: win.nav("artists") }
                NavItem { icon: "list-music"; label: "Çalma listeleri"; badge: win.playlists.length; active: win.view === "playlists"; onClicked: win.nav("playlists") }
                Item { width: 1; height: 8 }
                Rectangle { width: parent.width; height: 1; color: Theme.stroke; opacity: 0.8; visible: win.playlists.length > 0 }
                Item { width: 1; height: 6; visible: win.playlists.length > 0 }
                SectionLabel { text: "LİSTELERİM"; visible: win.playlists.length > 0 }
                Repeater {
                    model: win.playlists.slice(0, 6)
                    NavItem {
                        required property var modelData
                        required property int index
                        icon: "music-2"; label: modelData.name
                        active: win.view === "detail" && win.detail && win.detail.kind === "playlist" && win.detail.plIndex === index
                        onClicked: { win.prevView = []; win.openPlaylist(index); }
                    }
                }
            }
            Row {
                anchors { left: parent.left; bottom: parent.bottom; margins: 28; bottomMargin: 22 }
                spacing: 8
                Icon { name: "refresh-cw"; size: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter
                    RotationAnimation on rotation { running: win.scanning; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
                }
                Text {
                    text: win.scanning ? "Kitaplık taranıyor…" : "Kitaplığı yenile"
                    color: Theme.textDim; font { family: Theme.font; pixelSize: 12 }
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; onClicked: win.rescan() }
                }
            }
        }

        // --- İçerik ---
        Item {
            id: content
            anchors { left: sidebar.right; right: parent.right; top: header.bottom; bottom: nowBar.top }

            // sayfa başlığı (detay dışı)
            Column {
                id: pageHead
                visible: win.view !== "detail"
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 34; rightMargin: 32; topMargin: 32 }
                spacing: 6
                Text {
                    text: win.query ? "Arama" : ({ songs: "Şarkılar", albums: "Albümler", artists: "Sanatçılar", playlists: "Çalma listeleri" })[win.view]
                    color: Theme.text; font { family: Theme.font; pixelSize: 28 }
                }
                Text {
                    text: win.query ? "“" + win.query + "” için " + win.shownTracks.length + " şarkı" :
                          ({ songs: win.tracks.length + " şarkı", albums: win.albums.length + " albüm", artists: win.artists.length + " sanatçı", playlists: win.playlists.length + " liste" })[win.view]
                    color: Theme.textDim; font { family: Theme.font; pixelSize: 13 }
                }
            }
            PillButton {
                visible: win.view === "songs" && win.tracks.length > 0
                anchors { right: parent.right; rightMargin: 32; top: parent.top; topMargin: 32 }
                icon: "shuffle"; label: "Karışık çal"
                onClicked: win.playList(win.shownTracks, -1, true)
            }

            // Şarkılar
            SongList {
                id: songsList
                visible: win.view === "songs"
                anchors { fill: parent; topMargin: 104; leftMargin: 22; rightMargin: 22 }
                list: win.shownTracks
            }

            // Albümler
            GridView {
                id: albumGrid
                visible: win.view === "albums"
                anchors { fill: parent; topMargin: 104; leftMargin: 22; rightMargin: 22 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property int cols: Math.max(2, Math.floor(width / 196))
                cellWidth: Math.floor(width / cols)
                cellHeight: cellWidth + 62
                model: win.shownAlbums
                bottomMargin: 20
                delegate: Item {
                    required property var modelData
                    width: albumGrid.cellWidth; height: albumGrid.cellHeight
                    Rectangle {
                        anchors { fill: parent; margins: 6 }
                        radius: 16
                        color: am.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                        CoverArt {
                            id: albumCover
                            x: 10; y: 10
                            width: parent.width - 20; height: width
                            source: win.coverUrl(modelData); seed: modelData.title
                            scale: am.containsMouse ? 1.02 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
                        }
                        Column {
                            anchors { left: parent.left; right: parent.right; top: albumCover.bottom; margins: 12; topMargin: 12 }
                            spacing: 3
                            Text { width: parent.width; elide: Text.ElideRight; text: modelData.title; color: Theme.text; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
                            Text { width: parent.width; elide: Text.ElideRight; text: modelData.artist; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                        }
                        // oynat düğmesi
                        Rectangle {
                            width: 42; height: 42; radius: 21
                            anchors { right: albumCover.right; bottom: albumCover.bottom; margins: 10 }
                            color: Theme.accent
                            opacity: am.containsMouse ? 1 : 0
                            transform: Translate { y: am.containsMouse ? 0 : 8; Behavior on y { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } } }
                            Behavior on opacity { NumberAnimation { duration: Theme.dNormal } }
                            Icon { anchors.centerIn: parent; name: "play"; size: 18; color: Theme.accentInk }
                            MouseArea { anchors.fill: parent; onClicked: win.playList(modelData.tracks, -1) }
                        }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; z: -1; onClicked: win.openAlbum(modelData) }
                    }
                }
            }

            // Sanatçılar
            GridView {
                id: artistGrid
                visible: win.view === "artists"
                anchors { fill: parent; topMargin: 104; leftMargin: 22; rightMargin: 22 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property int cols: Math.max(2, Math.floor(width / 190))
                cellWidth: Math.floor(width / cols)
                cellHeight: 232
                model: win.shownArtists
                delegate: Item {
                    required property var modelData
                    width: artistGrid.cellWidth; height: artistGrid.cellHeight
                    Rectangle {
                        anchors { fill: parent; margins: 6 }
                        radius: 16
                        color: rmA.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                        CoverArt {
                            id: av
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 16 }
                            width: 128; height: 128; round: true
                            source: win.coverUrl(modelData); seed: modelData.name
                        }
                        Column {
                            anchors { left: parent.left; right: parent.right; top: av.bottom; margins: 10; topMargin: 14 }
                            spacing: 3
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.name; color: Theme.text; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.tracks.length + " şarkı"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                        }
                        MouseArea { id: rmA; anchors.fill: parent; hoverEnabled: true; onClicked: win.openArtist(modelData) }
                    }
                }
            }

            // Çalma listeleri
            GridView {
                id: plGrid
                visible: win.view === "playlists"
                anchors { fill: parent; topMargin: 104; leftMargin: 22; rightMargin: 22 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property int cols: Math.max(2, Math.floor(width / 196))
                cellWidth: Math.floor(width / cols)
                cellHeight: cellWidth + 62
                model: [{ isNew: true }].concat(win.playlists.map((p, i) => ({ isNew: false, idx: i, name: p.name, count: p.paths.length, cover: (win.byPath[p.paths[0]] || {}).cover || "" })))
                delegate: Item {
                    required property var modelData
                    width: plGrid.cellWidth; height: plGrid.cellHeight
                    Rectangle {
                        anchors { fill: parent; margins: 6 }
                        radius: 16
                        color: pm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                        Rectangle {
                            id: plc
                            visible: modelData.isNew
                            x: 10; y: 10; width: parent.width - 20; height: width; radius: 14
                            color: Qt.rgba(1, 1, 1, 0.03); border.width: 1; border.color: Theme.strokeHi
                            Icon { anchors.centerIn: parent; name: "plus"; size: 34; color: Theme.textDim }
                        }
                        CoverArt {
                            id: plc2
                            visible: !modelData.isNew
                            x: 10; y: 10; width: parent.width - 20; height: width
                            source: modelData.isNew ? "" : win.coverUrl({ cover: modelData.cover }); seed: modelData.name || ""
                        }
                        Column {
                            anchors { left: parent.left; right: parent.right; top: plc.bottom; margins: 12; topMargin: 12 }
                            spacing: 3
                            Text { width: parent.width; elide: Text.ElideRight; text: modelData.isNew ? "Yeni liste" : modelData.name; color: Theme.text; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
                            Text { width: parent.width; text: modelData.isNew ? "Çalma listesi oluştur" : modelData.count + " şarkı"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                        }
                        MouseArea {
                            id: pm; anchors.fill: parent; hoverEnabled: true
                            onClicked: modelData.isNew ? (win.namePath = "", win.nameOpen = true) : win.openPlaylist(modelData.idx)
                        }
                    }
                }
            }

            // Ayrıntı (albüm / sanatçı / liste)
            SongList {
                id: detailList
                visible: win.view === "detail" && win.detail !== null
                anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
                list: win.detail ? win.detail.tracks : []
                numbered: win.detail && win.detail.kind === "album"
                inPlaylist: win.detail && win.detail.kind === "playlist"
                plIndex: win.detail && win.detail.kind === "playlist" ? win.detail.plIndex : -1
                header: Item {
                    width: detailList.width; height: 250
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 30
                        CoverArt {
                            width: 190; height: 190
                            round: win.detail && win.detail.kind === "artist"
                            source: win.detail ? win.coverUrl({ cover: win.detail.cover }) : ""
                            seed: win.detail ? win.detail.title : ""
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text {
                                text: win.detail ? ({ album: "ALBÜM", artist: "SANATÇI", playlist: "ÇALMA LİSTESİ" })[win.detail.kind] : ""
                                color: Theme.textDim; font { family: Theme.font; pixelSize: 11; letterSpacing: 1.4; weight: Font.Medium }
                            }
                            Text { text: win.detail ? win.detail.title : ""; width: Math.min(560, detailList.width - 300); elide: Text.ElideRight; color: Theme.text; font { family: Theme.font; pixelSize: 34 } }
                            Text { text: win.detail ? win.detail.subtitle : ""; color: Theme.textDim; font { family: Theme.font; pixelSize: 14 } }
                            Item { width: 1; height: 8 }
                            Row {
                                spacing: 12
                                PillButton { icon: "play"; label: "Çal"; onClicked: win.playList(win.detail.tracks, -1) }
                                PillButton { primary: false; icon: "shuffle"; label: "Karıştır"; onClicked: win.playList(win.detail.tracks, -1, true) }
                                PillButton {
                                    visible: win.detail && win.detail.kind === "playlist"
                                    primary: false; icon: "trash-2"; label: "Sil"
                                    onClicked: win.deletePlaylist(win.detail.plIndex)
                                }
                            }
                        }
                    }
                }
            }

            // boş durum
            Column {
                visible: win.loaded && win.tracks.length === 0 && win.view !== "playlists"
                anchors.centerIn: parent
                spacing: 14
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "music"; size: 54; color: Theme.textFaint }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.scanning ? "Kitaplık taranıyor…" : "Henüz müzik yok"; color: Theme.text; font { family: Theme.font; pixelSize: 18 } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Şarkılarını Müzik klasörüne koy, kendiliğinden görünsünler."; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } }
            }
            Text {
                visible: win.query && win.view === "songs" && win.shownTracks.length === 0 && win.tracks.length > 0
                anchors.centerIn: parent
                text: "Sonuç bulunamadı"; color: Theme.textDim; font { family: Theme.font; pixelSize: 15 }
            }
        }

        // --- Alt çalma çubuğu ---
        Rectangle {
            id: nowBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 96
            color: Qt.rgba(8 / 255, 11 / 255, 17 / 255, 0.72)
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.stroke }
            RowLayout {
                anchors { fill: parent; leftMargin: 24; rightMargin: 24 }
                spacing: 24
                // sol: parça
                Item {
                    Layout.preferredWidth: 300; Layout.fillHeight: true
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        CoverArt { width: 62; height: 62; source: win.cur ? win.coverUrl(win.cur) : ""; seed: win.cur ? win.cur.album : "" }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            width: 210
                            Text { width: parent.width; elide: Text.ElideRight; text: win.cur ? win.cur.title : "Çalan bir şey yok"; color: Theme.text; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
                            Text { width: parent.width; elide: Text.ElideRight; text: win.cur ? win.cur.artist : "Bir şarkı seç"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                        }
                    }
                    MouseArea { anchors.fill: parent; enabled: win.cur !== null; cursorShape: Qt.PointingHandCursor; onClicked: win.full = true }
                }
                // orta: denetim + arama çubuğu
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        Ctl { icon: "shuffle"; iconSize: 18; on: win.shuffle; onClicked: win.shuffle = !win.shuffle; anchors.verticalCenter: parent.verticalCenter }
                        Ctl { icon: "skip-back"; onClicked: win.prev(); anchors.verticalCenter: parent.verticalCenter }
                        Ctl { primary: true; size: 48; iconSize: 22; icon: win.playing ? "pause" : "play"; onClicked: win.togglePause(); anchors.verticalCenter: parent.verticalCenter }
                        Ctl { icon: "skip-forward"; onClicked: win.next(); anchors.verticalCenter: parent.verticalCenter }
                        Ctl { icon: win.repeat === 2 ? "repeat-1" : "repeat"; iconSize: 18; on: win.repeat > 0; onClicked: win.cycleRepeat(); anchors.verticalCenter: parent.verticalCenter }
                    }
                    RowLayout {
                        width: parent.width
                        spacing: 12
                        Text { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; text: win.fmt(seekBar.shown * win.dur); color: Theme.textDim; font { family: Theme.font; pixelSize: 11 } }
                        Bar {
                            id: seekBar
                            Layout.fillWidth: true
                            value: win.dur > 0 ? win.pos / win.dur : 0
                            onChanging: v => win.pos = v * win.dur
                            onCommitted: v => win.seekTo(v * win.dur)
                        }
                        Text { Layout.preferredWidth: 40; text: win.fmt(win.dur); color: Theme.textDim; font { family: Theme.font; pixelSize: 11 } }
                    }
                }
                // sağ: ses
                RowLayout {
                    Layout.preferredWidth: 220
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    IconButton {
                        icon: win.muted || win.volume === 0 ? "volume-x" : (win.volume < 40 ? "volume-1" : "volume-2"); size: 34
                        onClicked: win.ctl(["cycle", "mute"])
                    }
                    Bar {
                        id: volBar
                        Layout.preferredWidth: 104
                        value: win.volume / 100
                        onChanging: v => { win.volume = v * 100; volTimer.restart(); }
                        onCommitted: v => win.setVolume(v * 100)
                    }
                    IconButton { icon: "maximize-2"; size: 34; iconSize: 16; opacity: win.cur ? 1 : 0.35; onClicked: if (win.cur) win.full = true }
                }
            }
            Timer { id: volTimer; interval: 90; onTriggered: if (volBar.dragging) win.setVolume(win.volume) }
        }

        // --- Tam ekran çalıyor ---
        Item {
            id: fullView
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: win.full ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.OutCubic } }
            transform: Translate { y: win.full ? 0 : 40; Behavior on y { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.OutCubic } } }

            Rectangle { anchors.fill: parent; color: "#0A0E15" }
            Image {
                id: bgSrc
                anchors.fill: parent
                source: win.cur ? win.coverUrl(win.cur) : ""
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectCrop
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: bgSrc
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 0.35
                brightness: -0.1
                visible: bgSrc.status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(8 / 255, 11 / 255, 17 / 255, 0.35) }
                    GradientStop { position: 1; color: Qt.rgba(8 / 255, 11 / 255, 17 / 255, 0.85) }
                }
            }
            MouseArea { anchors.fill: parent }   // alttaki arayüzü engelle
            MouseArea {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 74
                onPressed: win.startSystemMove()
            }
            RowLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 24; rightMargin: 18; topMargin: 20 }
                IconButton { icon: "chevron-down"; size: 40; iconSize: 22; onClicked: win.full = false }
                Item { Layout.fillWidth: true }
                Text { text: "ŞİMDİ ÇALIYOR"; color: Qt.rgba(1, 1, 1, 0.6); font { family: Theme.font; pixelSize: 11; letterSpacing: 2; weight: Font.Medium } }
                Item { Layout.fillWidth: true }
                IconButton { icon: "x"; size: 40; onClicked: win.close() }
            }

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 10
                spacing: 64
                Item {
                    width: Math.min(400, fullView.height - 300); height: width
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors { fill: parent; margins: -1 }
                        radius: 24; color: "transparent"
                    }
                    CoverArt {
                        anchors.fill: parent
                        radius: 22
                        source: win.cur ? win.coverUrl(win.cur) : ""; seed: win.cur ? win.cur.album : ""
                        scale: win.playing ? 1 : 0.94
                        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
                Column {
                    width: Math.min(460, fullView.width - 560)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text { width: parent.width; elide: Text.ElideRight; text: win.cur ? win.cur.title : ""; color: "#fff"; font { family: Theme.font; pixelSize: 36; weight: Font.DemiBold } }
                    Text { width: parent.width; elide: Text.ElideRight; text: win.cur ? win.cur.artist : ""; color: Qt.rgba(1, 1, 1, 0.75); font { family: Theme.font; pixelSize: 19 } }
                    Text { width: parent.width; elide: Text.ElideRight; text: win.cur ? win.cur.album : ""; color: Qt.rgba(1, 1, 1, 0.5); font { family: Theme.font; pixelSize: 14 } }
                    Item { width: 1; height: 24 }
                    Bar {
                        width: parent.width
                        thick: 5
                        value: seekBar.value
                        onChanging: v => win.pos = v * win.dur
                        onCommitted: v => win.seekTo(v * win.dur)
                        id: fullSeek
                    }
                    Item {
                        width: parent.width; height: 16
                        Text { text: win.fmt(win.pos); color: Qt.rgba(1, 1, 1, 0.6); font { family: Theme.font; pixelSize: 12 } }
                        Text { anchors.right: parent.right; text: win.fmt(win.dur); color: Qt.rgba(1, 1, 1, 0.6); font { family: Theme.font; pixelSize: 12 } }
                    }
                    Item { width: 1; height: 6 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16
                        Ctl { icon: "shuffle"; iconSize: 19; on: win.shuffle; onClicked: win.shuffle = !win.shuffle; anchors.verticalCenter: parent.verticalCenter }
                        Ctl { icon: "skip-back"; size: 48; iconSize: 24; onClicked: win.prev(); anchors.verticalCenter: parent.verticalCenter }
                        Ctl { primary: true; size: 68; iconSize: 28; icon: win.playing ? "pause" : "play"; onClicked: win.togglePause(); anchors.verticalCenter: parent.verticalCenter }
                        Ctl { icon: "skip-forward"; size: 48; iconSize: 24; onClicked: win.next(); anchors.verticalCenter: parent.verticalCenter }
                        Ctl { icon: win.repeat === 2 ? "repeat-1" : "repeat"; iconSize: 19; on: win.repeat > 0; onClicked: win.cycleRepeat(); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Item { width: 1; height: 10 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        Icon { name: win.muted || win.volume === 0 ? "volume-x" : "volume-2"; size: 18; color: Qt.rgba(1, 1, 1, 0.7); anchors.verticalCenter: parent.verticalCenter }
                        Bar {
                            width: 200
                            anchors.verticalCenter: parent.verticalCenter
                            value: win.volume / 100
                            onChanging: v => { win.volume = v * 100; volTimer.restart(); }
                            onCommitted: v => win.setVolume(v * 100)
                        }
                    }
                }
            }
        }

        // --- Listeye ekle menüsü ---
        MouseArea {
            anchors.fill: parent
            visible: win.menuOpen
            onClicked: win.menuOpen = false
        }
        Rectangle {
            id: addMenu
            visible: win.menuOpen
            x: win.menuX; y: win.menuY
            width: 260
            height: Math.min(330, menuCol.implicitHeight + 16)
            radius: 16
            color: "#161D2A"
            border.width: 1; border.color: Theme.strokeHi
            clip: true
            Flickable {
                anchors { fill: parent; margins: 8 }
                contentHeight: menuCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: menuCol
                    width: parent.width
                    spacing: 2
                    Text { text: "LİSTEYE EKLE"; leftPadding: 10; topPadding: 6; bottomPadding: 6; color: Theme.textDim; font { family: Theme.font; pixelSize: 11; letterSpacing: 1.4; weight: Font.Medium } }
                    Repeater {
                        model: win.playlists
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: menuCol.width; height: 38; radius: 10
                            color: mi.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                            Text { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10 } elide: Text.ElideRight; text: modelData.name; color: Theme.text; font { family: Theme.font; pixelSize: 13 } }
                            MouseArea { id: mi; anchors.fill: parent; hoverEnabled: true; onClicked: { win.addToPlaylist(index, win.menuTrack.path); win.menuOpen = false; } }
                        }
                    }
                    Rectangle {
                        width: menuCol.width; height: 38; radius: 10
                        color: mn.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        Row {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                            spacing: 10
                            Icon { name: "plus"; size: 16; color: Theme.accent }
                            Text { text: "Yeni liste…"; color: Theme.accent; font { family: Theme.font; pixelSize: 13 } }
                        }
                        MouseArea { id: mn; anchors.fill: parent; hoverEnabled: true; onClicked: { win.namePath = win.menuTrack.path; win.menuOpen = false; win.nameOpen = true; } }
                    }
                }
            }
        }

        // --- Yeni liste adı ---
        Rectangle {
            anchors.fill: parent
            visible: win.nameOpen
            color: Qt.rgba(0, 0, 0, 0.5)
            MouseArea { anchors.fill: parent; onClicked: win.nameOpen = false }
            Rectangle {
                anchors.centerIn: parent
                width: 380; height: 190; radius: 20
                color: "#161D2A"; border.width: 1; border.color: Theme.strokeHi
                MouseArea { anchors.fill: parent }
                Column {
                    anchors { fill: parent; margins: 24 }
                    spacing: 16
                    Text { text: "Yeni çalma listesi"; color: Theme.text; font { family: Theme.font; pixelSize: 18 } }
                    Rectangle {
                        width: parent.width; height: 44; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: nameInput.activeFocus ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.5) : Theme.stroke
                        TextInput {
                            id: nameInput
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text; font { family: Theme.font; pixelSize: 14 }
                            focus: win.nameOpen
                            onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                            Keys.onReturnPressed: { win.createPlaylist(text, win.namePath); win.nameOpen = false; }
                            Keys.onEscapePressed: win.nameOpen = false
                            Text { visible: !nameInput.text; text: "Liste adı"; color: Theme.textFaint; font: nameInput.font; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Row {
                        spacing: 10
                        anchors.right: parent.right
                        PillButton { primary: false; label: "Vazgeç"; icon: "x"; onClicked: win.nameOpen = false }
                        PillButton { label: "Oluştur"; icon: "plus"; onClicked: { win.createPlaylist(nameInput.text, win.namePath); win.nameOpen = false; } }
                    }
                }
            }
        }
    }
}
