import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"
import "../components"

// Başlat menüsü. Dock'taki logodan doğar, sağdan sola akarak genişler.
// Açılışta logodan suya düşen damla gibi bir halka yayılır.
PanelWindow {
    id: win
    required property var dockOrigin   // logonun ekran koordinatı
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Shell.startOpen || closeTimer.running
    WlrLayershell.namespace: "ayaz-start"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Shell.startOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool open: Shell.startOpen
    readonly property int panelW: Math.min(760, width - 220)
    readonly property int panelH: Math.min(640, height - 140)
    readonly property real ox: dockOrigin ? dockOrigin.x : width - 72
    readonly property real oy: dockOrigin ? dockOrigin.y : height / 2

    onOpenChanged: {
        if (open) { search.text = ""; search.forceActiveFocus(); ripple.restart(); }
        else closeTimer.restart();
    }
    Timer { id: closeTimer; interval: Theme.dSlow + 40 }

    // Arka planı hafif karart, boşluğa tıklayınca kapat.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.open ? 0.28 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: Shell.startOpen = false }
    }

    // Su halkası: logodan dışa yayılır.
    Rectangle {
        id: ring
        x: win.ox - width / 2; y: win.oy - height / 2
        width: 60; height: 60; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: 0
        SequentialAnimation {
            id: ripple
            ParallelAnimation {
                NumberAnimation { target: ring; property: "width"; from: 60; to: 900; duration: 900; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "height"; from: 60; to: 900; duration: 900; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.55; to: 0; duration: 900; easing.type: Easing.OutQuad }
            }
        }
    }

    // Menü paneli: kapalıyken logonun yerinde küçük bir karo, açıkken tam panel.
    Glass {
        id: panel
        readonly property real openX: win.width - 140 - win.panelW
        readonly property real openY: (win.height - win.panelH) / 2
        x: win.open ? openX : win.ox - 30
        y: win.open ? openY : win.oy - 30
        width: win.open ? win.panelW : 60
        height: win.open ? win.panelH : 60
        radius: win.open ? Theme.rWindow + 6 : 16
        opacity: win.open ? 1 : 0
        clip: true
        color: Qt.rgba(14 / 255, 19 / 255, 28 / 255, 0.86)
        border.color: Theme.strokeHi

        Behavior on x { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.OutQuint } }
        Behavior on width { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: Theme.dSlow + 60; easing.type: Easing.OutQuint } }
        Behavior on radius { NumberAnimation { duration: Theme.dSlow } }
        Behavior on opacity { NumberAnimation { duration: win.open ? 120 : Theme.dSlow; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent } // arkadaki kapatma alanına tıklama geçmesin

        // Üst kenardan süzülen ışık (cam parıltısı).
        Rectangle {
            width: parent.width * 0.6; height: 1
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.6) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        ColumnLayout {
            id: content
            width: win.panelW
            height: win.panelH
            opacity: win.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: win.open ? 320 : 100 } }
            spacing: 18

            // Arama
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 28
                Layout.bottomMargin: 0
                Layout.preferredHeight: 48
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: search.activeFocus ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.5) : Theme.stroke
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 12
                    Icon { name: "search"; size: 18; color: Theme.textDim }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 15 }
                        selectionColor: Theme.selected
                        Text {
                            visible: !search.text
                            text: "Uygulama, dosya veya ayar ara"
                            color: Theme.textFaint
                            font: search.font
                        }
                        Keys.onEscapePressed: Shell.startOpen = false
                        Keys.onReturnPressed: if (grid.count > 0) Shell.launch(grid.itemAtIndex(Math.max(0, grid.currentIndex)).entry.id)
                        Keys.onDownPressed: grid.moveCurrentIndexDown()
                        Keys.onUpPressed: grid.moveCurrentIndexUp()
                        Keys.onRightPressed: grid.moveCurrentIndexRight()
                        Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                        onTextChanged: grid.currentIndex = 0
                    }
                }
            }

            Text {
                Layout.leftMargin: 32
                text: search.text ? "Sonuçlar" : "Tüm uygulamalar"
                color: Theme.textDim
                font { family: Theme.font; pixelSize: 12; letterSpacing: 1.2; capitalization: Font.AllUppercase; weight: Font.Medium }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                clip: true
                cellWidth: Math.floor(width / 6)
                cellHeight: 108
                currentIndex: 0
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: {
                        const q = search.text.toLowerCase();
                        return DesktopEntries.applications.values
                            .filter(e => !e.noDisplay && (!q || e.name.toLowerCase().includes(q)
                                || (e.genericName ?? "").toLowerCase().includes(q)
                                || (e.keywords ?? []).some(k => k.toLowerCase().includes(q))))
                            .sort((a, b) => a.name.localeCompare(b.name, "tr"));
                    }
                }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property var entry: modelData
                    width: grid.cellWidth
                    height: grid.cellHeight

                    // Sağdan sola kademeli giriş.
                    opacity: win.open ? 1 : 0
                    transform: Translate { x: win.open ? 0 : 40 }
                    Behavior on opacity { NumberAnimation { duration: 260 + Math.min(cell.index, 18) * 18; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors { fill: parent; margins: 6 }
                        radius: Theme.rCard
                        color: cellMouse.containsMouse || (grid.currentIndex === cell.index && search.text) ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 44
                            source: Quickshell.iconPath(cell.entry.icon, "application-x-executable")
                            scale: cellMouse.pressed ? 0.9 : (cellMouse.containsMouse ? 1.06 : 1)
                            Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }
                        }
                        Text {
                            width: grid.cellWidth - 16
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.entry.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Shell.launch(cell.entry.id)
                    }
                }
            }

            // Alt şerit: kullanıcı ve güç düğmeleri.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                color: Qt.rgba(0, 0, 0, 0.18)
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.stroke }
                RowLayout {
                    anchors { fill: parent; leftMargin: 28; rightMargin: 20 }
                    spacing: 6
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.violet }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: (Quickshell.env("USER") ?? "?").charAt(0).toUpperCase()
                            color: Theme.accentInk
                            font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                        }
                    }
                    Text {
                        Layout.leftMargin: 8
                        text: Quickshell.env("USER") ?? ""
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
                    }
                    Item { Layout.fillWidth: true }
                    IconButton { icon: "lock"; onClicked: { Shell.startOpen = false; Sys.lock(); } }
                    IconButton { icon: "moon"; onClicked: { Shell.startOpen = false; Sys.suspend(); } }
                    IconButton { icon: "rotate-ccw"; onClicked: Sys.reboot() }
                    IconButton { icon: "power"; tint: Theme.danger; onClicked: Sys.poweroff() }
                }
            }
        }
    }
}
