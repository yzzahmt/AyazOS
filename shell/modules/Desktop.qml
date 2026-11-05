import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../services"
import "../components"

// Masaüstü katmanı: duvar kağıdı, selamlama, müzik bileşeni, çalışma alanı göstergesi.
PanelWindow {
    id: desk
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.base
    WlrLayershell.namespace: "ayaz-desktop"
    WlrLayershell.layer: WlrLayer.Background

    property string wallpaper: "/usr/share/backgrounds/ayazos/default.jpg"

    Image {
        anchors.fill: parent
        source: "file://" + desk.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(desk.width, desk.height)
    }
    // Okunurluk için sol üstte yumuşak gölge.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0) }
        }
    }

    // Selamlama
    Column {
        x: 92; y: 96
        spacing: 10
        Text {
            text: Sys.dateLong
            color: Theme.text
            opacity: 0.85
            font { family: Theme.font; pixelSize: 17; letterSpacing: 2.4; weight: Font.Medium }
        }
        Text {
            text: Shell.focusMode ? "Odaktasın." : "Kendine alan aç."
            color: Theme.text
            font { family: Theme.font; pixelSize: 40; weight: Font.Normal }
        }
    }

    // Müzik bileşeni (MPRIS)
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    Glass {
        id: media
        visible: opacity > 0
        opacity: desk.player ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dNormal } }
        x: 88
        anchors { bottom: parent.bottom; bottomMargin: 56 }
        width: 536; height: 110
        radius: 18

        RowLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 16
            Rectangle {
                Layout.preferredWidth: 72; Layout.preferredHeight: 72
                radius: 12
                color: Theme.glassHi
                clip: true
                Image {
                    anchors.fill: parent
                    source: desk.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: desk.player?.trackTitle || "—"
                    elide: Text.ElideRight
                    color: Theme.text
                    font { family: Theme.font; pixelSize: 15; weight: Font.Medium }
                }
                Text {
                    Layout.fillWidth: true
                    text: [desk.player?.trackArtist, desk.player?.trackAlbum].filter(x => x).join(" · ")
                    elide: Text.ElideRight
                    color: Theme.textDim
                    font { family: Theme.font; pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.topMargin: 8
                    height: 3; radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle {
                        height: parent.height; radius: 1.5
                        color: Theme.accent
                        width: desk.player && desk.player.length > 0 ? parent.width * desk.player.position / desk.player.length : 0
                    }
                }
                Text {
                    text: desk.player ? fmt(desk.player.position) + " / " + fmt(desk.player.length) : ""
                    color: Theme.textFaint
                    font { family: Theme.font; pixelSize: 10; features: { "tnum": 1 } }
                    function fmt(s) { s = Math.floor(s || 0); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
                }
            }
            IconButton { icon: "skip-back"; onClicked: desk.player?.previous() }
            Rectangle {
                Layout.preferredWidth: 46; Layout.preferredHeight: 46
                radius: 23
                color: Theme.accent
                Icon { anchors.centerIn: parent; size: 20; color: Theme.accentInk; name: desk.player?.isPlaying ? "pause" : "play" }
                MouseArea { anchors.fill: parent; onClicked: desk.player?.togglePlaying() }
            }
            IconButton { icon: "skip-forward"; onClicked: desk.player?.next() }
        }
        // Konumu saniyede bir güncelle (yalnızca çalarken).
        Timer {
            running: desk.player?.isPlaying ?? false
            interval: 1000; repeat: true
            onTriggered: desk.player.positionChanged()
        }
    }

    Text {
        anchors { right: parent.right; rightMargin: 290; bottom: parent.bottom; bottomMargin: 62 }
        text: "Çalışma alanı " + String(Shell.workspace).padStart(2, "0") + "  /  " + String(Shell.workspaceCount).padStart(2, "0")
        color: Theme.text
        opacity: 0.8
        font { family: Theme.font; pixelSize: 15; features: { "tnum": 1 } }
    }
}
