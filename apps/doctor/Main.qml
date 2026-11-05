import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import AyazOS.UI
import AyazOS.Native

// AyazOS Sistem Doktoru
Window {
    id: win
    width: 1240
    height: 820
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Sistem Doktoru"

    readonly property string appDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    readonly property string backend: appDir + "bin/ayaz-doctor"
    readonly property color okC: "#7FD6A0"
    readonly property color warnC: "#F2C46D"
    readonly property color failC: Theme.danger

    property string page: "health"        // health | system | advanced
    property var checks: []
    property bool scanning: false
    property bool scanned: false
    property int total: 11
    property string fixing: ""
    property string fixLog: ""
    property string notice: ""
    property bool noticeOk: true
    property var cpuH: []
    property var ramH: []
    property var tmpH: []
    property var st: ({ cpu: 0, ram_used: 0, ram_total: 1, disk_used: 0, disk_total: 1, temp: null, load: 0 })
    property string actionBusy: ""

    function sh(args) { return [backend].concat(args); }
    function score() {
        let s = 100;
        checks.forEach(c => { if (c.status === "fail") s -= 22; else if (c.status === "warn") s -= 9; });
        return Math.max(0, s);
    }
    readonly property int sc: score()
    readonly property color scColor: !scanned ? Theme.accent : sc >= 85 ? okC : sc >= 60 ? warnC : failC
    function verdict() {
        if (scanning) return "Taranıyor…";
        if (!scanned) return "Sistemini tek tıkla denetle";
        if (sc >= 95) return "Harika, her şey yolunda";
        if (sc >= 80) return "İyi durumda";
        if (sc >= 60) return "Birkaç şey dikkat istiyor";
        return "Düzeltmen gereken sorunlar var";
    }
    function statusColor(s) { return s === "ok" ? okC : s === "warn" ? warnC : failC; }
    function startScan() {
        if (scanning) return;
        checks = []; scanning = true; scanned = false; notice = "";
        scanProc.startWith(sh(["scan"]));
    }
    function replaceCheck(c) {
        const a = checks.slice();
        const i = a.findIndex(x => x.id === c.id);
        if (i >= 0) a[i] = c; else a.push(c);
        checks = a;
    }
    function fix(id) {
        if (fixing !== "") return;
        fixing = id; fixLog = ""; notice = "";
        fixProc.startWith(sh(["fix", id]));
    }
    function runAction(name, label) {
        if (actionBusy !== "") return;
        actionBusy = name; notice = "";
        actProc.label = label;
        actProc.startWith(sh(["action", name]));
    }
    function pushHist(arr, v) { const a = arr.concat([v]); return a.length > 45 ? a.slice(a.length - 45) : a; }
    function fmt(n) { return Fs.formatSize(n); }

    Component.onCompleted: {
        statsProc.startWith(sh(["stats"]));
        if (appArgs.length > 0) { if (appArgs[0] === "scan") startScan(); else page = appArgs[0]; }
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: if (!statsProc.running) statsProc.startWith(win.sh(["stats"])) }

    Proc {
        id: statsProc
        onFinished: (code, out) => {
            try {
                const o = JSON.parse(out.trim().split("\n")[0]);
                win.st = o;
                win.cpuH = win.pushHist(win.cpuH, o.cpu);
                win.ramH = win.pushHist(win.ramH, o.ram_used / o.ram_total * 100);
                win.tmpH = win.pushHist(win.tmpH, o.temp === null ? 0 : o.temp);
            } catch (e) {}
        }
    }
    Proc {
        id: scanProc
        onLine: text => { try { const o = JSON.parse(text); if (o.type === "check") win.replaceCheck(o); } catch (e) {} }
        onFinished: { win.scanning = false; win.scanned = true; }
    }
    Proc {
        id: fixProc
        onLine: text => { try { const o = JSON.parse(text); if (o.type === "log") win.fixLog = o.text; } catch (e) {} }
        onFinished: (code, out) => {
            const id = win.fixing;
            let ok = code === 0;
            out.split("\n").forEach(l => { try { const o = JSON.parse(l); if (o.type === "done") ok = o.ok; } catch (e) {} });
            win.noticeOk = ok;
            win.notice = ok ? "Düzeltme tamamlandı." : "Düzeltme tamamlanamadı. Yetki penceresi iptal edilmiş olabilir.";
            win.fixing = "";
            recheck.startWith(win.sh(["check", id]));
        }
    }
    Proc {
        id: recheck
        onFinished: (code, out) => out.split("\n").forEach(l => { try { const o = JSON.parse(l); if (o.type === "check") win.replaceCheck(o); } catch (e) {} })
    }
    Proc {
        id: actProc
        property string label: ""
        onFinished: (code) => {
            win.actionBusy = "";
            win.noticeOk = code === 0;
            win.notice = code === 0 ? label + ": tamamlandı." : label + ": tamamlanamadı.";
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
                    spacing: 12
                    Icon { name: "stethoscope"; size: 22 }
                    Text { text: "Sistem Doktoru"; color: Theme.text; font { family: Theme.font; pixelSize: 17; weight: Font.DemiBold } }
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
            width: 236
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.stroke }
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 28 }
                spacing: 4
                SectionLabel { text: "DOKTOR" }
                NavItem { icon: "shield-check"; label: "Sağlık"; active: win.page === "health"; onClicked: win.page = "health" }
                NavItem { icon: "activity"; label: "Sistem"; active: win.page === "system"; onClicked: win.page = "system" }
                NavItem { icon: "wrench"; label: "Gelişmiş"; active: win.page === "advanced"; onClicked: win.page = "advanced" }
            }
            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 28; bottomMargin: 36 }
                spacing: 10
                MiniBar { label: "İşlemci"; value: win.st.cpu / 100 }
                MiniBar { label: "Bellek"; value: win.st.ram_used / win.st.ram_total }
                MiniBar { label: "Disk"; value: win.st.disk_used / win.st.disk_total }
            }
        }

        // --- İçerik ---
        Item {
            id: content
            anchors { left: sidebar.right; right: parent.right; top: header.bottom; bottom: parent.bottom }

            // ===== Sağlık =====
            Item {
                anchors.fill: parent
                visible: win.page === "health"

                // Halka
                Item {
                    id: ringBox
                    anchors { left: parent.left; top: parent.top; leftMargin: 34; topMargin: 34 }
                    width: 330; height: parent.height - 68
                    Rectangle {
                        anchors.fill: parent; radius: 22
                        color: Qt.rgba(1, 1, 1, 0.03); border.width: 1; border.color: Theme.stroke
                    }
                    Item {
                        id: ring
                        width: 250; height: 250
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 34 }
                        property real shown: win.scanned ? win.sc : 0
                        Behavior on shown { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }
                        property real spin: 0
                        NumberAnimation on spin { running: win.scanning; from: 0; to: 360; duration: 1300; loops: Animation.Infinite }
                        onShownChanged: cv.requestPaint()
                        onSpinChanged: if (win.scanning) cv.requestPaint()
                        Connections { target: win; function onScColorChanged() { cv.requestPaint(); } function onScanningChanged() { cv.requestPaint(); } }
                        Canvas {
                            id: cv
                            anchors.fill: parent
                            antialiasing: true
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const c = width / 2, r = c - 14, lw = 16;
                                ctx.lineCap = "round";
                                ctx.lineWidth = lw;
                                ctx.strokeStyle = "rgba(255,255,255,0.07)";
                                ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke();
                                ctx.strokeStyle = win.scColor;
                                ctx.beginPath();
                                if (win.scanning) {
                                    const a0 = (ring.spin - 90) * Math.PI / 180;
                                    ctx.arc(c, c, r, a0, a0 + Math.PI * 0.55);
                                } else {
                                    const frac = ring.shown / 100;
                                    if (frac > 0.001) ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
                                }
                                ctx.stroke();
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: win.scanned ? Math.round(ring.shown) : "—"
                                color: Theme.text
                                font { family: Theme.font; pixelSize: 68; weight: Font.Light }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: win.scanned ? "SAĞLIK PUANI" : win.scanning ? win.checks.length + " / " + win.total : "HAZIR"
                                color: Theme.textDim
                                font { family: Theme.font; pixelSize: 11; letterSpacing: 1.6; weight: Font.Medium }
                            }
                        }
                    }
                    Text {
                        id: vtext
                        anchors { top: ring.bottom; topMargin: 22; left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24 }
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: win.verdict()
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 18 }
                    }
                    Text {
                        anchors { top: vtext.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24 }
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: win.scanned
                        text: {
                            const f = win.checks.filter(c => c.status !== "ok").length;
                            return f === 0 ? "Düzeltilecek bir şey yok." : f + " madde için dikkat gerekiyor.";
                        }
                        color: Theme.textDim
                        font { family: Theme.font; pixelSize: 13 }
                    }
                    PrimaryButton {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
                        width: 230
                        label: win.scanning ? "Taranıyor…" : win.scanned ? "Yeniden tara" : "Taramayı başlat"
                        icon: "stethoscope"
                        opacity: win.scanning ? 0.6 : 1
                        onClicked: win.startScan()
                    }
                }

                // Denetim listesi
                Item {
                    anchors { left: ringBox.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 28 }
                    Text {
                        id: lt
                        anchors { left: parent.left; top: parent.top; topMargin: 34 }
                        text: "Denetimler"; color: Theme.text; font { family: Theme.font; pixelSize: 24 }
                    }
                    Toast { anchors { right: parent.right; rightMargin: 32; verticalCenter: lt.verticalCenter }; visible: win.notice !== "" && win.page === "health" }
                    ListView {
                        anchors { left: parent.left; right: parent.right; top: lt.bottom; bottom: parent.bottom; topMargin: 18; rightMargin: 32 }
                        clip: true; spacing: 8; bottomMargin: 30
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.checks
                        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 } NumberAnimation { property: "x"; from: 24; to: 0; duration: 250; easing.type: Easing.OutCubic } }
                        delegate: Rectangle {
                            id: cardR
                            required property var modelData
                            width: ListView.view.width; height: 72; radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.width: 1; border.color: modelData.status === "ok" ? Theme.stroke : Qt.rgba(win.statusColor(modelData.status).r, win.statusColor(modelData.status).g, win.statusColor(modelData.status).b, 0.35)
                            RowLayout {
                                anchors { fill: parent; leftMargin: 18; rightMargin: 16 }
                                spacing: 14
                                Rectangle {
                                    Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6
                                    color: win.statusColor(modelData.status)
                                    Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: parent.color; opacity: 0.18 }
                                }
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { text: modelData.title; color: Theme.text; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
                                    Text {
                                        width: parent.width; elide: Text.ElideRight
                                        text: win.fixing === modelData.id && win.fixLog ? win.fixLog : modelData.detail
                                        color: Theme.textDim; font { family: Theme.font; pixelSize: 12 }
                                    }
                                }
                                GhostButton {
                                    visible: modelData.fix !== "" && modelData.status !== "ok" && win.fixing !== modelData.id
                                    label: "Düzelt"; icon: "wrench"
                                    opacity: win.fixing === "" ? 1 : 0.4
                                    onClicked: win.fix(modelData.id)
                                }
                                Item {
                                    visible: win.fixing === modelData.id
                                    Layout.preferredWidth: 90; Layout.preferredHeight: 40
                                    Row {
                                        anchors.centerIn: parent; spacing: 8
                                        Item {
                                            width: 18; height: 18
                                            RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: win.fixing === cardR.modelData.id }
                                            Icon { name: "refresh-cw"; size: 18; color: Theme.accent }
                                        }
                                        Text { text: "Onarılıyor"; color: Theme.accent; font { family: Theme.font; pixelSize: 12 }; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }
                        }
                        Column {
                            visible: win.checks.length === 0
                            anchors.centerIn: parent
                            spacing: 12
                            Icon { name: "stethoscope"; size: 48; color: Theme.textFaint; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "Taramayı başlatınca sonuçlar burada görünür"; color: Theme.textDim; font { family: Theme.font; pixelSize: 14 } }
                        }
                    }
                }
            }

            // ===== Sistem =====
            Item {
                anchors.fill: parent
                visible: win.page === "system"
                Column {
                    id: sh1
                    anchors { left: parent.left; top: parent.top; leftMargin: 34; topMargin: 32 }
                    spacing: 6
                    Text { text: "Sistem"; color: Theme.text; font { family: Theme.font; pixelSize: 28 } }
                    Text { text: "Canlı durum, 2 saniyede bir yenilenir"; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } }
                }
                GridLayout {
                    anchors { left: parent.left; right: parent.right; top: sh1.bottom; topMargin: 26; leftMargin: 34; rightMargin: 32 }
                    columns: 2; rowSpacing: 16; columnSpacing: 16
                    StatCard {
                        Layout.fillWidth: true
                        title: "İŞLEMCİ"; value: Math.round(win.st.cpu) + "%"
                        sub: "Yük ortalaması " + win.st.load.toFixed(2)
                        hist: win.cpuH; maxV: 100; tint: Theme.accent
                    }
                    StatCard {
                        Layout.fillWidth: true
                        title: "BELLEK"; value: win.fmt(win.st.ram_used)
                        sub: "Toplam " + win.fmt(win.st.ram_total)
                        hist: win.ramH; maxV: 100; tint: "#B79CF5"
                    }
                    StatCard {
                        Layout.fillWidth: true
                        title: "SICAKLIK"
                        value: win.st.temp === null ? "—" : Math.round(win.st.temp) + "°C"
                        sub: win.st.temp === null ? "Bu cihazda sıcaklık sensörü yok" : (win.st.temp > 80 ? "Biraz sıcak" : "Normal")
                        hist: win.tmpH; maxV: 100; tint: "#F2C46D"
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 190; radius: 18
                        color: Qt.rgba(1, 1, 1, 0.035); border.width: 1; border.color: Theme.stroke
                        Column {
                            anchors { fill: parent; margins: 22 }
                            spacing: 10
                            Text { text: "DİSK"; color: Theme.textDim; font { family: Theme.font; pixelSize: 11; letterSpacing: 1.5; weight: Font.Medium } }
                            Text { text: win.fmt(win.st.disk_total - win.st.disk_used) + " boş"; color: Theme.text; font { family: Theme.font; pixelSize: 32; weight: Font.Light } }
                            Text { text: win.fmt(win.st.disk_used) + " / " + win.fmt(win.st.disk_total) + " kullanımda"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
                            Rectangle {
                                width: parent.width; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.08)
                                Rectangle { width: parent.width * win.st.disk_used / win.st.disk_total; height: 8; radius: 4; color: Theme.accent }
                            }
                        }
                    }
                }
            }

            // ===== Gelişmiş =====
            Item {
                anchors.fill: parent
                visible: win.page === "advanced"
                Column {
                    id: ah
                    anchors { left: parent.left; top: parent.top; leftMargin: 34; topMargin: 32 }
                    spacing: 6
                    Text { text: "Gelişmiş"; color: Theme.text; font { family: Theme.font; pixelSize: 28 } }
                    Text { text: "Tek tıkla yaygın onarımlar"; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } }
                }
                Toast { anchors { right: parent.right; rightMargin: 32; verticalCenter: ah.verticalCenter }; visible: win.notice !== "" && win.page === "advanced" }
                GridLayout {
                    anchors { left: parent.left; right: parent.right; top: ah.bottom; topMargin: 26; leftMargin: 34; rightMargin: 32 }
                    columns: 2; rowSpacing: 16; columnSpacing: 16
                    ActionCard { Layout.fillWidth: true; icon: "trash-2"; title: "Önbelleği temizle"; desc: "Paket önbelleğini ve eski kayıtları siler, yer açar."; name: "clean-cache"; label: "Önbellek temizliği" }
                    ActionCard { Layout.fillWidth: true; icon: "wifi"; title: "Ağı sıfırla"; desc: "Ağ hizmetini yeniden başlatır. İnternet sorunlarında işe yarar."; name: "reset-network"; label: "Ağ sıfırlama" }
                    ActionCard { Layout.fillWidth: true; icon: "volume-2"; title: "Sesi sıfırla"; desc: "Ses hizmetlerini yeniden başlatır. Ses gelmiyorsa dene."; name: "reset-sound"; label: "Ses sıfırlama" }
                    ActionCard { Layout.fillWidth: true; icon: "trash"; title: "Çöp kutusunu boşalt"; desc: "Çöpteki tüm dosyaları kalıcı olarak siler."; name: "empty-trash"; label: "Çöp kutusu" }
                    ActionCard { Layout.fillWidth: true; icon: "monitor"; title: "Masaüstünü yeniden başlat"; desc: "Panel ve masaüstü kabuğunu yeniler. Açık pencerelerin korunur."; name: "restart-shell"; label: "Masaüstü yenileme" }
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
        }
        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: nav.clicked() }
    }
    component MiniBar: Column {
        property string label
        property real value: 0
        width: parent ? parent.width : 150
        spacing: 6
        Row {
            width: parent.width
            Text { text: label; color: Theme.textDim; width: parent.width - pc.implicitWidth; font { family: Theme.font; pixelSize: 12 } }
            Text { id: pc; text: Math.round(value * 100) + "%"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
        }
        Rectangle {
            width: parent.width; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.10)
            Rectangle { width: parent.width * Math.min(1, Math.max(0, value)); height: 3; radius: 1.5; color: value > 0.9 ? win.failC : Theme.accent; Behavior on width { NumberAnimation { duration: 400 } } }
        }
    }
    component PrimaryButton: Rectangle {
        id: pb
        property string label
        property string icon
        signal clicked()
        implicitWidth: pr.implicitWidth + 44
        width: implicitWidth; height: 46
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
        signal clicked()
        implicitWidth: gr.implicitWidth + 36
        width: implicitWidth; height: 40
        radius: 12
        color: gm.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1; border.color: Theme.strokeHi
        Row {
            id: gr
            anchors.centerIn: parent
            spacing: 8
            Icon { visible: gb.icon !== ""; name: gb.icon; size: 16; anchors.verticalCenter: parent.verticalCenter }
            Text { text: gb.label; color: Theme.text; font { family: Theme.font; pixelSize: 14 } }
        }
        MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gb.clicked() }
    }
    component Toast: Rectangle {
        implicitWidth: tt.implicitWidth + 36; implicitHeight: 38
        radius: 12
        color: win.noticeOk ? Qt.rgba(120 / 255, 200 / 255, 150 / 255, 0.16) : Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.14)
        border.width: 1; border.color: win.noticeOk ? Qt.rgba(120 / 255, 200 / 255, 150 / 255, 0.4) : Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.4)
        Text { id: tt; anchors.centerIn: parent; text: win.notice; color: win.noticeOk ? "#9BE0B4" : Theme.danger; font { family: Theme.font; pixelSize: 13 } }
    }
    component StatCard: Rectangle {
        id: sc2
        property string title
        property string value
        property string sub
        property var hist: []
        property real maxV: 100
        property color tint: Theme.accent
        Layout.preferredHeight: 190
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.035); border.width: 1; border.color: Theme.stroke
        onHistChanged: spark.requestPaint()
        Column {
            anchors { left: parent.left; top: parent.top; margins: 22 }
            spacing: 8
            Text { text: sc2.title; color: Theme.textDim; font { family: Theme.font; pixelSize: 11; letterSpacing: 1.5; weight: Font.Medium } }
            Text { text: sc2.value; color: Theme.text; font { family: Theme.font; pixelSize: 36; weight: Font.Light } }
            Text { text: sc2.sub; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
        }
        Canvas {
            id: spark
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: 76
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const h = sc2.hist;
                if (h.length < 2) return;
                const step = width / 44;
                const x0 = width - (h.length - 1) * step;
                const y = v => height - 8 - (Math.min(sc2.maxV, Math.max(0, v)) / sc2.maxV) * (height - 20);
                const grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, Qt.rgba(sc2.tint.r, sc2.tint.g, sc2.tint.b, 0.28));
                grad.addColorStop(1, Qt.rgba(sc2.tint.r, sc2.tint.g, sc2.tint.b, 0));
                ctx.beginPath();
                ctx.moveTo(x0, height);
                h.forEach((v, i) => ctx.lineTo(x0 + i * step, y(v)));
                ctx.lineTo(x0 + (h.length - 1) * step, height);
                ctx.closePath();
                ctx.fillStyle = grad; ctx.fill();
                ctx.beginPath();
                h.forEach((v, i) => i === 0 ? ctx.moveTo(x0, y(v)) : ctx.lineTo(x0 + i * step, y(v)));
                ctx.strokeStyle = sc2.tint; ctx.lineWidth = 2; ctx.lineJoin = "round"; ctx.stroke();
            }
        }
    }
    component ActionCard: Rectangle {
        id: ac
        property string icon
        property string title
        property string desc
        property string name
        property string label
        Layout.preferredHeight: 104
        radius: 16
        color: am.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.035)
        border.width: 1; border.color: am.containsMouse ? Theme.strokeHi : Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
            spacing: 16
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 14
                color: Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.12)
                Icon { anchors.centerIn: parent; name: ac.icon; size: 22; color: Theme.accent }
            }
            Column {
                Layout.fillWidth: true
                spacing: 5
                Text { text: ac.title; color: Theme.text; font { family: Theme.font; pixelSize: 15; weight: Font.Medium } }
                Text { text: ac.desc; width: parent.width; wrapMode: Text.WordWrap; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
            }
            Text {
                visible: win.actionBusy === ac.name
                text: "Çalışıyor…"; color: Theme.accent; font { family: Theme.font; pixelSize: 12 }
            }
        }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.runAction(ac.name, ac.label) }
    }
}
