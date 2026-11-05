import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import AyazOS.UI
import AyazOS.Native

// AyazOS Dosyalar
Window {
    id: win
    width: 1240
    height: 820
    minimumWidth: 860
    minimumHeight: 560
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Dosyalar"

    // --- durum ---
    property string place: "home"          // home | recent | starred | trash | dir | search
    property string path: Fs.home
    property var history: []
    property int historyPos: -1
    property var items: []
    property int selected: -1
    property string sortKey: "mtime"
    property bool sortDesc: true
    property bool grid: false
    property bool showHidden: false
    property string query: ""
    property string renaming: ""
    readonly property string trashDir: Fs.home + "/.local/share/Trash/files"

    function go(newPlace, newPath, keepHistory) {
        place = newPlace;
        path = newPath || "";
        selected = -1;
        query = "";
        search.text = "";
        if (!keepHistory) {
            history = history.slice(0, historyPos + 1).concat([{ place: newPlace, path: newPath }]);
            historyPos = history.length - 1;
        }
        reload();
    }
    function back() { if (historyPos > 0) { historyPos--; const h = history[historyPos]; go(h.place, h.path, true); } }
    function forward() { if (historyPos < history.length - 1) { historyPos++; const h = history[historyPos]; go(h.place, h.path, true); } }

    function reload() {
        let list = [];
        if (place === "home" || place === "recent") list = Array.from(Fs.recent(place === "home" ? 5 : 60));
        else if (place === "starred") list = Array.from(Fs.starred()).filter(p => Fs.exists(p)).map(p => Fs.info(p));
        else if (place === "search") list = items;
        else list = Array.from(Fs.list(path, showHidden, sortKey, sortDesc));
        if (place !== "dir" && place !== "trash" && place !== "search") {
            list.sort((a, b) => {
                let r = sortKey === "name" ? a.name.localeCompare(b.name, "tr") : sortKey === "size" ? a.size - b.size : a.mtime - b.mtime;
                return sortDesc ? -r : r;
            });
        }
        items = list;
    }

    function openItem(it) {
        if (!it) return;
        if (it.dir) go("dir", it.path);
        else Fs.open(it.path);
    }

    function title() {
        switch (place) {
        case "home": return "Başlangıç";
        case "recent": return "Son kullanılanlar";
        case "starred": return "Yıldızlı";
        case "trash": return "Çöp Kutusu";
        case "search": return "Arama";
        default: return path === Fs.home ? "Ev" : path.split("/").pop();
        }
    }
    function subtitle() {
        switch (place) {
        case "home": return "Her şey, bıraktığın yerde.";
        case "recent": return "Son açtığın dosyalar";
        case "starred": return "Yıldızladığın dosya ve klasörler";
        case "trash": return items.length + " öğe çöpte";
        case "search": return "“" + query + "” için " + items.length + " sonuç";
        default: return items.length + " öğe";
        }
    }

    Connections { target: Fs; function onChanged(dir) { win.reload(); } }
    Component.onCompleted: go(appArgs.length > 0 ? (appArgs[0] === "trash:///" ? "trash" : "dir") : "home",
                              appArgs.length > 0 ? (appArgs[0] === "trash:///" ? Fs.home + "/.local/share/Trash/files" : appArgs[0]) : "")

    Proc {
        id: finder
        onFinished: (code, out) => {
            win.items = out.split("\n").filter(l => l).slice(0, 300).map(p => Fs.info(p));
            win.place = "search";
            win.selected = -1;
        }
    }
    Timer {
        id: searchDelay
        interval: 250
        onTriggered: {
            if (!win.query) { win.go("home", ""); return; }
            const root = win.place === "dir" ? win.path : Fs.home;
            finder.startWith(["find", root, "-maxdepth", "6", "-not", "-path", "*/.*", "-iname", "*" + win.query + "*"]);
        }
    }

    Shortcut { sequences: ["Ctrl+K", "Ctrl+F"]; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Alt+Left"; onActivated: win.back() }
    Shortcut { sequence: "Alt+Right"; onActivated: win.forward() }
    Shortcut { sequence: "Ctrl+H"; onActivated: { win.showHidden = !win.showHidden; win.reload(); } }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: newFolder() }
    Shortcut { sequence: "Delete"; onActivated: if (win.selected >= 0) Fs.trash([win.items[win.selected].path]) }
    Shortcut { sequence: "F2"; onActivated: if (win.selected >= 0) win.renaming = win.items[win.selected].path }
    Shortcut { sequence: "Return"; onActivated: win.openItem(win.items[win.selected]) }

    function newFolder() {
        const base = (place === "dir") ? path : Fs.home;
        let name = "Yeni klasör", n = 2;
        while (Fs.exists(base + "/" + name)) name = "Yeni klasör " + n++;
        Fs.mkdir(base + "/" + name);
        if (place !== "dir") go("dir", base);
        renaming = base + "/" + name;
    }

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
                    Icon { name: "folder"; size: 22 }
                    Text { text: "Dosyalar"; color: Theme.text; font { family: Theme.font; pixelSize: 17; weight: Font.DemiBold } }
                }
                IconButton { icon: "chevron-left"; size: 32; opacity: win.historyPos > 0 ? 1 : 0.35; onClicked: win.back() }
                IconButton { icon: "chevron-right"; size: 32; opacity: win.historyPos < win.history.length - 1 ? 1 : 0.35; onClicked: win.forward() }

                // Konum yolu
                Row {
                    Layout.leftMargin: 10
                    spacing: 8
                    Icon { name: "house"; size: 17; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: {
                            if (win.place !== "dir") return [{ label: Fs.home.split("/").pop(), path: Fs.home, dim: true }, { label: win.title(), path: "", dim: false }];
                            const rel = win.path.startsWith(Fs.home) ? win.path.slice(Fs.home.length) : win.path;
                            const parts = rel.split("/").filter(p => p);
                            let acc = win.path.startsWith(Fs.home) ? Fs.home : "";
                            const out = [{ label: Fs.home.split("/").pop(), path: Fs.home, dim: parts.length > 0 }];
                            parts.forEach((p, i) => { acc += "/" + p; out.push({ label: p, path: acc, dim: i < parts.length - 1 }); });
                            return out.slice(-4);
                        }
                        Row {
                            required property var modelData
                            required property int index
                            spacing: 8
                            Icon { visible: index > 0; name: "chevron-right"; size: 14; color: Theme.textFaint; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: modelData.label
                                color: modelData.dim ? Theme.textDim : Theme.text
                                font { family: Theme.font; pixelSize: 15 }
                                MouseArea { anchors.fill: parent; enabled: modelData.path !== ""; onClicked: win.go("dir", modelData.path) }
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }

                // Arama
                Rectangle {
                    Layout.preferredWidth: 228; Layout.preferredHeight: 40
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
                            onTextEdited: { win.query = text; searchDelay.restart(); }
                            Keys.onEscapePressed: { text = ""; win.query = ""; win.go("home", ""); focus = false; }
                            Text {
                                visible: !search.text
                                text: "Dosyalarda ara"
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
                SectionLabel { text: "KISAYOLLAR" }
                NavItem { icon: "house"; label: "Başlangıç"; active: win.place === "home"; onClicked: win.go("home", "") }
                NavItem { icon: "clock"; label: "Son kullanılanlar"; active: win.place === "recent"; onClicked: win.go("recent", "") }
                NavItem { icon: "star"; label: "Yıldızlı"; active: win.place === "starred"; onClicked: win.go("starred", "") }
                NavItem {
                    icon: "download"; label: "İndirilenler"
                    badge: Fs.countEntries(Fs.userDir("DOWNLOAD"))
                    active: win.place === "dir" && win.path === Fs.userDir("DOWNLOAD")
                    onClicked: win.go("dir", Fs.userDir("DOWNLOAD"))
                }
                NavItem { icon: "file-text"; label: "Belgeler"; active: win.place === "dir" && win.path === Fs.userDir("DOCUMENTS"); onClicked: win.go("dir", Fs.userDir("DOCUMENTS")) }
                NavItem { icon: "image"; label: "Görseller"; active: win.place === "dir" && win.path === Fs.userDir("PICTURES"); onClicked: win.go("dir", Fs.userDir("PICTURES")) }
                NavItem { icon: "trash-2"; label: "Çöp Kutusu"; active: win.place === "trash"; onClicked: win.go("trash", win.trashDir) }
                Rectangle { width: parent.width; height: 1; color: Theme.stroke; opacity: 0.8 }
                Item { width: 1; height: 6 }
                SectionLabel { text: "AYGITLAR" }
                NavItem { icon: "hard-drive"; label: "Yerel disk"; active: win.place === "dir" && win.path === "/"; onClicked: win.go("dir", "/") }
                Repeater {
                    model: Fs.list("/media/" + Fs.home.split("/").pop(), false, "name", false)
                    NavItem {
                        required property var modelData
                        icon: "hard-drive-download"; label: modelData.name
                        active: win.place === "dir" && win.path === modelData.path
                        onClicked: win.go("dir", modelData.path)
                    }
                }
            }

            // Disk doluluğu
            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 28; bottomMargin: 40 }
                spacing: 10
                readonly property var st: Fs.storage(Fs.home)
                Rectangle {
                    width: parent.width; height: 3; radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Rectangle {
                        width: parent.width * (1 - parent.parent.st.free / Math.max(1, parent.parent.st.total))
                        height: parent.height; radius: 1.5
                        color: Theme.accent
                    }
                }
                Text {
                    text: Fs.formatSize(parent.st.free) + " kullanılabilir"
                    color: Theme.textDim
                    font { family: Theme.font; pixelSize: 12 }
                }
            }
        }

        // --- İçerik ---
        Item {
            id: content
            anchors { left: sidebar.right; right: parent.right; top: header.bottom; bottom: parent.bottom }

            // Başlık + yeni klasör
            RowLayout {
                id: pageHead
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 34; rightMargin: 32; topMargin: 32 }
                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    Text { text: win.title(); color: Theme.text; font { family: Theme.font; pixelSize: 28; weight: Font.Normal } }
                    Text { text: win.subtitle(); color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } }
                }
                Rectangle {
                    visible: win.place === "trash"
                    Layout.preferredWidth: 140; Layout.preferredHeight: 44; radius: 12
                    color: Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.14)
                    border.width: 1; border.color: Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.35)
                    Text { anchors.centerIn: parent; text: "Çöpü boşalt"; color: Theme.danger; font { family: Theme.font; pixelSize: 14; weight: Font.Medium } }
                    MouseArea { anchors.fill: parent; onClicked: emptyTrash.startWith(["gio", "trash", "--empty"]) }
                    Proc { id: emptyTrash; onFinished: win.reload() }
                }
                Rectangle {
                    visible: win.place !== "trash"
                    Layout.preferredWidth: 140; Layout.preferredHeight: 44
                    radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#B8CCF6" }
                        GradientStop { position: 1; color: "#9DB7EE" }
                    }
                    scale: nfMouse.pressed ? 0.96 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dFast } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 10
                        Icon { name: "plus"; size: 17; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Yeni klasör"; color: Theme.accentInk; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
                    }
                    MouseArea { id: nfMouse; anchors.fill: parent; onClicked: win.newFolder() }
                }
            }

            // Klasör kartları (yalnızca Başlangıç)
            Row {
                id: cards
                visible: win.place === "home"
                anchors { left: parent.left; right: parent.right; top: pageHead.bottom; leftMargin: 34; rightMargin: 32; topMargin: 24 }
                spacing: 16
                height: visible ? 130 : 0
                readonly property var folders: {
                    const starredDirs = Fs.starred().filter(p => Fs.exists(p)).map(p => Fs.info(p)).filter(i => i.dir);
                    const userDirs = Fs.list(Fs.home, false, "mtime", true).filter(i => i.dir);
                    const seen = {};
                    return starredDirs.concat(userDirs).filter(i => !seen[i.path] && (seen[i.path] = true)).slice(0, 3);
                }
                Repeater {
                    model: cards.folders
                    Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        width: (cards.width - 32) / 3
                        height: 130
                        radius: Theme.rCard
                        color: cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.025)
                        border.width: 1
                        border.color: Theme.stroke
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                        Icon { x: 18; y: 20; name: "folder"; size: 34 }
                        Icon { anchors { right: parent.right; top: parent.top; margins: 18 } name: ["pen-tool", "code-xml", "user"][card.index]; size: 15; color: Theme.textDim }
                        Text { x: 18; anchors { bottom: parent.bottom; bottomMargin: 38 } text: card.modelData.name; color: Theme.text; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
                        Text {
                            anchors { right: parent.right; bottom: parent.bottom; margins: 18; bottomMargin: 38 }
                            text: Fs.countEntries(card.modelData.path) + " öğe"
                            color: Theme.textDim
                            font { family: Theme.font; pixelSize: 12 }
                        }
                        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; onClicked: win.go("dir", card.modelData.path) }
                    }
                }
            }

            // Liste başlığı: "Son kullanılanlar" + sıralama + görünüm
            RowLayout {
                id: listHead
                anchors { left: parent.left; right: parent.right; top: cards.visible ? cards.bottom : pageHead.bottom; leftMargin: 34; rightMargin: 32; topMargin: cards.visible ? 34 : 22 }
                Text {
                    text: win.place === "home" ? "Son kullanılanlar" : ""
                    color: Theme.text
                    font { family: Theme.font; pixelSize: 16 }
                }
                Item { Layout.fillWidth: true }
                Row {
                    spacing: 6
                    Text {
                        text: ({ mtime: "Son değiştirilme", name: "Ad", size: "Boyut" })[win.sortKey]
                        color: Theme.textDim
                        font { family: Theme.font; pixelSize: 12 }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Icon { name: "chevron-down"; size: 15; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    MouseArea {
                        width: 130; height: 24; x: -110
                        onClicked: {
                            const keys = ["mtime", "name", "size"];
                            win.sortKey = keys[(keys.indexOf(win.sortKey) + 1) % 3];
                            win.sortDesc = win.sortKey !== "name";
                            win.reload();
                        }
                    }
                }
                Item { Layout.preferredWidth: 10 }
                IconButton { icon: "list"; size: 32; active: !win.grid; onClicked: win.grid = false }
                IconButton { icon: "layout-grid"; size: 32; active: win.grid; onClicked: win.grid = true }
            }

            // Sütun başlıkları
            RowLayout {
                id: cols
                visible: !win.grid
                anchors { left: parent.left; right: parent.right; top: listHead.bottom; leftMargin: 50; rightMargin: 46; topMargin: 18 }
                Text { Layout.fillWidth: true; text: "Ad"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                Text { Layout.preferredWidth: 210; text: "Değiştirilme"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                Text { Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight; text: "Boyut"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
            }

            // Liste görünümü
            ListView {
                id: list
                visible: !win.grid
                anchors { left: parent.left; right: parent.right; top: cols.bottom; bottom: footer.top; leftMargin: 34; rightMargin: 32; topMargin: 10 }
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: win.items
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: win.selected === index
                    width: list.width
                    height: 60
                    radius: 10
                    color: sel ? Theme.selected : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                    border.width: sel ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 14 }
                        spacing: 16
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 10
                            color: Qt.rgba(1, 1, 1, 0.04)
                            Icon { anchors.centerIn: parent; name: row.modelData.icon; size: 20 }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                visible: win.renaming !== row.modelData.path
                                width: parent.width
                                text: row.modelData.name
                                elide: Text.ElideMiddle
                                color: Theme.text
                                font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
                            }
                            TextInput {
                                visible: win.renaming === row.modelData.path
                                width: parent.width
                                text: row.modelData.name
                                color: Theme.text
                                selectByMouse: true
                                font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
                                onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
                                onAccepted: {
                                    const dir = row.modelData.path.substring(0, row.modelData.path.lastIndexOf("/"));
                                    if (text && text !== row.modelData.name) Fs.rename(row.modelData.path, dir + "/" + text);
                                    win.renaming = "";
                                }
                                Keys.onEscapePressed: win.renaming = ""
                            }
                            Text {
                                text: row.modelData.parent
                                color: Theme.textFaint
                                font { family: Theme.font; pixelSize: 11 }
                            }
                        }
                        Text {
                            Layout.preferredWidth: 210
                            text: Fs.formatTime(row.modelData.mtime)
                            color: Theme.textDim
                            font { family: Theme.font; pixelSize: 13 }
                        }
                        Text {
                            Layout.preferredWidth: 90
                            horizontalAlignment: Text.AlignRight
                            text: row.modelData.dir ? Fs.countEntries(row.modelData.path) + " öğe" : Fs.formatSize(row.modelData.size)
                            color: Theme.textDim
                            font { family: Theme.font; pixelSize: 13 }
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            win.selected = row.index;
                            if (m.button === Qt.RightButton) menu.openAt(row.modelData, mapToItem(frame, m.x, m.y));
                        }
                        onDoubleClicked: win.openItem(row.modelData)
                    }
                }
            }

            // Izgara görünümü
            GridView {
                id: gridView
                visible: win.grid
                anchors { left: parent.left; right: parent.right; top: listHead.bottom; bottom: footer.top; leftMargin: 28; rightMargin: 28; topMargin: 16 }
                clip: true
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 150)))
                cellHeight: 140
                model: win.items
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: gridView.cellWidth; height: gridView.cellHeight
                    Rectangle {
                        anchors { fill: parent; margins: 6 }
                        radius: Theme.rCard
                        color: win.selected === cell.index ? Theme.selected : (cellMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: cell.modelData.icon; size: 42 }
                        Text {
                            width: gridView.cellWidth - 24
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.modelData.name
                            elide: Text.ElideMiddle
                            color: Theme.text
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            win.selected = cell.index;
                            if (m.button === Qt.RightButton) menu.openAt(cell.modelData, mapToItem(frame, m.x, m.y));
                        }
                        onDoubleClicked: win.openItem(cell.modelData)
                    }
                }
            }

            // Boş durum
            Column {
                anchors.centerIn: list
                visible: win.items.length === 0
                spacing: 10
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: win.place === "trash" ? "trash-2" : "folder"; size: 40; color: Theme.textFaint }
                Text { text: win.place === "trash" ? "Çöp kutusu boş" : "Burada henüz bir şey yok"; color: Theme.textDim; font { family: Theme.font; pixelSize: 14 } }
            }

            // Alt bilgi
            RowLayout {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 34; rightMargin: 32; bottomMargin: 18 }
                height: 32
                Text {
                    text: win.items.length + " öğe" + (win.selected >= 0 ? " · 1 seçili" : "")
                    color: Theme.textDim
                    font { family: Theme.font; pixelSize: 12 }
                }
                Item { Layout.fillWidth: true }
                Icon { name: "shield-check"; size: 14; color: Theme.textDim }
                Text { text: "Bu cihazda saklanıyor"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
            }
        }

        // --- Sağ tık menüsü ---
        Glass {
            id: menu
            property var target: null
            visible: false
            width: 210
            height: menuCol.implicitHeight + 12
            radius: 12
            color: Theme.glassSolid
            border.color: Theme.strokeHi
            z: 10
            function openAt(it, p) {
                target = it;
                x = Math.min(p.x, frame.width - width - 8);
                y = Math.min(p.y, frame.height - height - 8);
                visible = true;
            }
            Column {
                id: menuCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                MenuRow { icon: "external-link"; label: "Aç"; onClicked: win.openItem(menu.target) }
                MenuRow { icon: "pencil"; label: "Yeniden adlandır"; onClicked: win.renaming = menu.target.path }
                MenuRow {
                    readonly property bool on: menu.target && Fs.starred().indexOf(menu.target.path) >= 0
                    icon: "star"; label: on ? "Yıldızı kaldır" : "Yıldızla"
                    onClicked: { Fs.setStarred(menu.target.path, !on); win.reload(); }
                }
                MenuRow { icon: "copy"; label: "Yolu kopyala"; onClicked: Proc.detached(["wl-copy", menu.target.path]) }
                MenuRow { icon: "trash-2"; label: win.place === "trash" ? "Kalıcı olarak sil" : "Çöpe taşı"; danger: true
                    onClicked: win.place === "trash" ? Proc.detached(["rm", "-rf", menu.target.path]) : Fs.trash([menu.target.path]) }
            }
        }
        MouseArea {
            anchors.fill: parent
            visible: menu.visible
            z: 9
            onClicked: menu.visible = false
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
        height: 46
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
            Text { visible: nav.badge > 0; text: nav.badge; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
        }
        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: nav.clicked() }
    }
    component MenuRow: Rectangle {
        id: mr
        property string icon
        property string label
        property bool danger: false
        signal clicked()
        width: parent ? parent.width : 200
        height: 36
        radius: 8
        color: mrMouse.containsMouse ? Theme.hover : "transparent"
        Row {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 10
            Icon { name: mr.icon; size: 15; color: mr.danger ? Theme.danger : Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: mr.label; color: mr.danger ? Theme.danger : Theme.text; font { family: Theme.font; pixelSize: 13 } }
        }
        MouseArea { id: mrMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { menu.visible = false; mr.clicked(); } }
    }
}
