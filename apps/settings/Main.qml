import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import AyazOS.UI
import AyazOS.Native
import "components"

// AyazOS Ayarlar
Window {
    id: win
    width: 1120
    height: 760
    minimumWidth: 860
    minimumHeight: 560
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Ayarlar"

    readonly property var pages: [
        { id: "appearance", icon: "palette", label: "Görünüm", sub: "Duvar kağıdı, vurgu rengi ve cam efekti", kw: "duvar kağıdı tema renk vurgu cam animasyon wallpaper" },
        { id: "display", icon: "monitor", label: "Ekran", sub: "Çözünürlük, yenileme hızı, ölçek ve gece ışığı", kw: "çözünürlük ölçek gece ışığı monitör hz" },
        { id: "sound", icon: "volume-2", label: "Ses", sub: "Çıkış ve giriş aygıtları, ses düzeyi", kw: "hoparlör mikrofon ses volume" },
        { id: "network", icon: "wifi", label: "Ağ ve İnternet", sub: "Wi-Fi ve kablolu bağlantılar", kw: "wifi kablosuz ethernet internet bağlantı" },
        { id: "bluetooth", icon: "bluetooth", label: "Bluetooth", sub: "Aygıt eşleştirme ve bağlantılar", kw: "kulaklık eşleştir aygıt" },
        { id: "power", icon: "battery-charging", label: "Güç ve Pil", sub: "Güç profili, pil sağlığı ve zaman aşımları", kw: "pil batarya uyku ekran kapat performans" },
        { id: "input", icon: "keyboard", label: "Klavye ve Fare", sub: "Düzen, tekrar hızı, dokunmatik yüzey", kw: "klavye fare touchpad imleç kaydırma düzen" },
        { id: "security", icon: "shield-check", label: "Kullanıcılar ve Güvenlik", sub: "Hesap, parola ve kilit", kw: "parola şifre kilit hesap kullanıcı" },
        { id: "updates", icon: "refresh-cw", label: "Güncellemeler", sub: "Sistem ve uygulama güncellemeleri", kw: "güncelle yazılım paket" },
        { id: "about", icon: "info", label: "Hakkında", sub: "Cihaz bilgisi ve sürüm", kw: "sürüm donanım cpu gpu ram bilgisayar adı" }
    ]
    property string current: "appearance"
    property string query: ""
    readonly property var shown: pages.filter(p => !query || (p.label + " " + p.kw).toLowerCase().indexOf(query.toLowerCase()) >= 0)

    function openPage(id) {
        if (id === current) return;
        current = id;
        loader.source = "pages/" + id + ".qml";
    }
    Component.onCompleted: {
        Sh.menuHost = menuLayer;
        Sh.dialogHost = dialogLayer;
        Sh.toastHost = toastLayer;
        const a = appArgs.length > 0 ? appArgs[0] : "";
        if (pages.some(p => p.id === a)) current = a;
        loader.source = "pages/" + current + ".qml";
    }
    Shortcut { sequences: ["Ctrl+K", "Ctrl+F"]; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Escape"; onActivated: { menuLayer.close(); dialogLayer.close(); } }

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
                    spacing: 12
                    Icon { name: "settings"; size: 22 }
                    Text { text: "Ayarlar"; color: Theme.text; font { family: Theme.font; pixelSize: 17; weight: Font.DemiBold } }
                }
                Item { Layout.fillWidth: true }
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
            width: 268
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.stroke }

            Rectangle {
                id: searchBox
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14; topMargin: 20 }
                height: 40
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: search.activeFocus ? Qt.rgba(Sh.accent.r, Sh.accent.g, Sh.accent.b, 0.45) : Theme.stroke
                Behavior on border.color { ColorAnimation { duration: Theme.dFast } }
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
                        onTextChanged: win.query = text
                        Keys.onEscapePressed: { text = ""; focus = false; }
                        Keys.onReturnPressed: if (win.shown.length > 0) win.openPage(win.shown[0].id)
                        Text {
                            visible: !search.text
                            text: "Ayarlarda ara"
                            color: Theme.textFaint
                            font: search.font
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Text { visible: !search.text; text: "Ctrl K"; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11 } }
                }
            }
            Column {
                anchors { left: parent.left; right: parent.right; top: searchBox.bottom; margins: 14; topMargin: 16 }
                spacing: 4
                Repeater {
                    model: win.shown
                    NavItem {
                        required property var modelData
                        icon: modelData.icon
                        label: modelData.label
                        active: win.current === modelData.id
                        onClicked: win.openPage(modelData.id)
                    }
                }
                Text {
                    visible: win.shown.length === 0
                    leftPadding: 14; topPadding: 12
                    text: "Eşleşen ayar yok"
                    color: Theme.textFaint
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
        }

        // --- İçerik ---
        Item {
            id: content
            anchors { left: sidebar.right; right: parent.right; top: header.bottom; bottom: parent.bottom }
            clip: true
            Loader {
                id: loader
                anchors.fill: parent
                asynchronous: false
                onLoaded: { fade.restart(); }
                onStatusChanged: if (status === Loader.Error) console.log("Sayfa yüklenemedi: " + source)
            }
            ParallelAnimation {
                id: fade
                NumberAnimation { target: loader; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: loader; property: "anchors.topMargin"; from: 16; to: 0; duration: 300; easing.type: Easing.OutCubic }
            }
        }

        // --- Bildirim ---
        Rectangle {
            id: toastLayer
            property string msg: ""
            function show(m) { msg = m; opacity = 1; toastTimer.restart(); }
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
            width: toastText.implicitWidth + 44; height: 44; radius: 22
            color: Qt.rgba(28 / 255, 36 / 255, 50 / 255, 0.96)
            border.width: 1; border.color: Theme.strokeHi
            opacity: 0
            visible: opacity > 0
            z: 50
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Text { id: toastText; anchors.centerIn: parent; text: toastLayer.msg; color: Theme.text; font { family: Theme.font; pixelSize: 13 } }
            Timer { id: toastTimer; interval: 2800; onTriggered: toastLayer.opacity = 0 }
        }

        // --- Açılır menü katmanı ---
        Item {
            id: menuLayer
            anchors.fill: parent
            z: 60
            visible: false
            property var options: []
            property var cur: null
            property var cb: null
            property real mx: 0
            property real my: 0
            property real mw: 160
            function open(anchor, opts, current, callback) {
                options = opts; cur = current; cb = callback;
                const p = anchor.mapToItem(menuLayer, 0, 0);
                mw = Math.max(anchor.width, 180);
                mx = Math.max(12, Math.min(menuLayer.width - mw - 12, p.x + anchor.width - mw));
                const h = Math.min(opts.length, 8) * 38 + 12;
                my = p.y + anchor.height + 6 + h > menuLayer.height - 10 ? p.y - h - 6 : p.y + anchor.height + 6;
                visible = true;
                pop.restart();
            }
            function close() { visible = false; }
            MouseArea { anchors.fill: parent; onPressed: menuLayer.close() }
            Rectangle {
                id: menuBox
                x: menuLayer.mx; y: menuLayer.my
                width: menuLayer.mw
                height: Math.min(menuLayer.options.length, 8) * 38 + 12
                radius: 14
                color: Qt.rgba(24 / 255, 31 / 255, 44 / 255, 0.97)
                border.width: 1; border.color: Theme.strokeHi
                transformOrigin: Item.Top
                ParallelAnimation {
                    id: pop
                    NumberAnimation { target: menuBox; property: "opacity"; from: 0; to: 1; duration: 140 }
                    NumberAnimation { target: menuBox; property: "scale"; from: 0.94; to: 1; duration: 180; easing.type: Easing.OutCubic }
                }
                ListView {
                    anchors { fill: parent; margins: 6 }
                    model: menuLayer.options
                    clip: true
                    interactive: contentHeight > height
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 38; radius: 9
                        color: mm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text {
                            anchors { left: parent.left; leftMargin: 12; right: chk.left; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: modelData.label
                            color: Theme.text
                            font { family: Theme.font; pixelSize: 13 }
                        }
                        Icon { id: chk; visible: modelData.value === menuLayer.cur; name: "check"; size: 15; color: Sh.accent; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } }
                        MouseArea {
                            id: mm
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { const f = menuLayer.cb; menuLayer.close(); if (f) f(modelData.value); }
                        }
                    }
                }
            }
        }

        // --- Diyalog katmanı ---
        Item {
            id: dialogLayer
            anchors.fill: parent
            z: 70
            visible: opacity > 0
            opacity: 0
            property var spec: ({ title: "", message: "", fields: [], ok: "Tamam", danger: false })
            property var cb: null
            Behavior on opacity { NumberAnimation { duration: 180 } }
            function open(s, callback) {
                spec = Object.assign({ title: "", message: "", fields: [], ok: "Tamam", danger: false }, s);
                cb = callback;
                for (let i = 0; i < 3; i++) fieldRep.itemAt(i).text = "";
                opacity = 1;
                dlgBox.scale = 0.92;
                dlgBox.scale = 1;
                if (spec.fields.length > 0) fieldRep.itemAt(0).input.forceActiveFocus();
            }
            function close() { opacity = 0; }
            function submit() {
                const v = [];
                for (let i = 0; i < spec.fields.length; i++) v.push(fieldRep.itemAt(i).text);
                const f = cb; close();
                if (f) f(v);
            }
            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }
            MouseArea { anchors.fill: parent; onClicked: dialogLayer.close() }
            Rectangle {
                id: dlgBox
                anchors.centerIn: parent
                width: 420
                height: dlgCol.implicitHeight + 56
                radius: 20
                color: Qt.rgba(22 / 255, 29 / 255, 42 / 255, 0.98)
                border.width: 1; border.color: Theme.strokeHi
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
                MouseArea { anchors.fill: parent }
                Column {
                    id: dlgCol
                    x: 28; y: 28
                    width: parent.width - 56
                    spacing: 14
                    Text { text: dialogLayer.spec.title; color: Theme.text; font { family: Theme.font; pixelSize: 19; weight: Font.Medium } }
                    Text {
                        visible: dialogLayer.spec.message !== ""
                        width: parent.width; wrapMode: Text.Wrap
                        text: dialogLayer.spec.message; color: Theme.textDim
                        font { family: Theme.font; pixelSize: 13 }
                    }
                    Repeater {
                        id: fieldRep
                        model: 3
                        Field {
                            required property int index
                            visible: index < dialogLayer.spec.fields.length
                            width: dlgCol.width
                            height: visible ? 42 : 0
                            placeholder: visible ? dialogLayer.spec.fields[index].placeholder : ""
                            password: visible ? !!dialogLayer.spec.fields[index].password : false
                            onAccepted: if (index === dialogLayer.spec.fields.length - 1) dialogLayer.submit()
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 10
                        PillButton { text: "Vazgeç"; onClicked: dialogLayer.close() }
                        PillButton { text: dialogLayer.spec.ok; kind: dialogLayer.spec.danger ? "danger" : "primary"; onClicked: dialogLayer.submit() }
                    }
                }
            }
        }
    }

    component NavItem: Rectangle {
        id: nav
        property string icon
        property string label
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
            Icon { name: nav.icon; size: 19; color: nav.active ? Sh.accent : Theme.textDim }
            Text {
                Layout.fillWidth: true
                text: nav.label
                elide: Text.ElideRight
                color: nav.active ? Theme.text : "#C3CAD6"
                font { family: Theme.font; pixelSize: 14; weight: nav.active ? Font.Medium : Font.Normal }
            }
        }
        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: nav.clicked() }
    }
}
