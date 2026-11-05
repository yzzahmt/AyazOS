import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services"
import "../components"

// Kontrol merkezi: ağ, odak, güç profili, ses ve parlaklık. Sağ üstten aşağı açılır.
PanelWindow {
    id: cc
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Shell.controlOpen || hideTimer.running
    WlrLayershell.namespace: "ayaz-control"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Shell.controlOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool open: Shell.controlOpen
    onOpenChanged: if (open) { profileQuery.running = true; brightQuery.running = true; } else hideTimer.restart()
    Timer { id: hideTimer; interval: Theme.dNormal + 40 }

    MouseArea { anchors.fill: parent; onClicked: Shell.controlOpen = false }

    property string profile: "balanced"
    property real brightness: -1

    Process {
        id: profileQuery
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector { onStreamFinished: cc.profile = text.trim() }
    }
    Process {
        id: brightQuery
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); cc.brightness = isNaN(v) ? -1 : v / 100; } }
    }
    function setProfile(p) { profile = p; Quickshell.execDetached(["powerprofilesctl", "set", p]); }
    function setBrightness(v) { brightness = v; Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(Math.max(0.05, v) * 100) + "%"]); }

    Glass {
        id: panel
        width: 380
        height: col.implicitHeight + 40
        x: cc.width - width - 16
        y: cc.open ? 54 : 30
        opacity: cc.open ? 1 : 0
        scale: cc.open ? 1 : 0.96
        transformOrigin: Item.TopRight
        radius: Theme.rWindow
        color: Qt.rgba(14 / 255, 19 / 255, 28 / 255, 0.88)
        Behavior on y { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.dNormal } }
        Behavior on scale { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors { fill: parent; margins: 20 }
            spacing: 14

            GridLayout {
                columns: 2
                columnSpacing: 10; rowSpacing: 10
                Layout.fillWidth: true
                Toggle {
                    icon: Sys.netKind === "none" ? "wifi-off" : "wifi"
                    title: "Wi-Fi"
                    subtitle: Sys.netName || "Bağlı değil"
                    on: Sys.netKind !== "none"
                    onToggled: Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "off" : "on"])
                }
                Toggle {
                    icon: "bluetooth"; title: "Bluetooth"; subtitle: "Ayarlar"
                    onToggled: Shell.launch("ayaz-settings")
                }
                Toggle {
                    icon: "moon"; title: "Odak"; subtitle: Shell.focusMode ? "Açık" : "Kapalı"
                    on: Shell.focusMode
                    onToggled: Shell.focusMode = !Shell.focusMode
                }
                Toggle {
                    icon: "lock"; title: "Kilitle"; subtitle: "Şimdi"
                    onToggled: { Shell.controlOpen = false; Sys.lock(); }
                }
            }

            // Güç profili
            Text { text: "Güç kipi"; color: Theme.textDim; font { family: Theme.font; pixelSize: 12 } }
            Rectangle {
                Layout.fillWidth: true; height: 44; radius: 14
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1; border.color: Theme.stroke
                RowLayout {
                    anchors { fill: parent; margins: 4 }
                    spacing: 4
                    Repeater {
                        model: [
                            { id: "power-saver", label: "Pil", icon: "battery-medium" },
                            { id: "balanced", label: "Dengeli", icon: "sparkles" },
                            { id: "performance", label: "Performans", icon: "zap" }
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
                            color: cc.profile === modelData.id ? Theme.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.dFast } }
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Icon { name: modelData.icon; size: 14; color: cc.profile === modelData.id ? Theme.accentInk : Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: modelData.label
                                    color: cc.profile === modelData.id ? Theme.accentInk : Theme.text
                                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                                }
                            }
                            MouseArea { anchors.fill: parent; onClicked: cc.setProfile(modelData.id) }
                        }
                    }
                }
            }

            SliderRow { icon: Sys.muted ? "volume-x" : "volume-2"; value: Sys.volume; onMoved: v => Sys.setVolume(v) }
            SliderRow { visible: cc.brightness >= 0; icon: "sun"; value: Math.max(0, cc.brightness); onMoved: v => cc.setBrightness(v) }
        }
    }

    component Toggle: Rectangle {
        id: t
        property string icon
        property string title
        property string subtitle
        property bool on: false
        signal toggled()
        Layout.fillWidth: true
        height: 64; radius: 16
        color: on ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.18) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: on ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.35) : Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
            spacing: 12
            Rectangle {
                width: 34; height: 34; radius: 17
                color: t.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                Icon { anchors.centerIn: parent; name: t.icon; size: 16; color: t.on ? Theme.accentInk : Theme.text }
            }
            Column {
                Layout.fillWidth: true
                Text { text: t.title; color: Theme.text; font { family: Theme.font; pixelSize: 13; weight: Font.Medium } }
                Text { width: parent.width; elide: Text.ElideRight; text: t.subtitle; color: Theme.textDim; font { family: Theme.font; pixelSize: 11 } }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: t.toggled() }
    }

    component SliderRow: RowLayout {
        id: s
        property string icon
        property real value
        signal moved(real v)
        Layout.fillWidth: true
        spacing: 12
        Icon { name: s.icon; size: 18 }
        Item {
            Layout.fillWidth: true; height: 28
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 8; radius: 4
                color: Qt.rgba(1, 1, 1, 0.10)
                Rectangle {
                    width: Math.max(height, parent.width * s.value); height: parent.height; radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: "#C9D8FA" }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                function upd(m) { s.moved(Math.max(0, Math.min(1, m.x / width))); }
                onPressed: m => upd(m)
                onPositionChanged: m => { if (pressed) upd(m); }
            }
        }
    }
}
