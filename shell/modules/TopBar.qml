import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"
import "../components"

// Üst çubuk: logo, etkin uygulama, durum simgeleri, tarih ve saat.
PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "ayaz-topbar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property var active: ToplevelManager.activeToplevel

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(8 / 255, 11 / 255, 17 / 255, 0.72)
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.stroke }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 14 }
        spacing: 4

        // Logo: başlat menüsünü açar.
        Item {
            Layout.preferredWidth: 36; Layout.preferredHeight: 32
            Rectangle {
                anchors.fill: parent; radius: 9
                color: logoMouse.containsMouse || Shell.startOpen ? Theme.hover : "transparent"
            }
            Image {
                anchors.centerIn: parent
                width: 22; height: 22
                sourceSize: Qt.size(44, 44)
                source: Qt.resolvedUrl("../assets/ayazos-mark.svg")
            }
            MouseArea { id: logoMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Shell.toggleStart() }
        }

        Text {
            Layout.leftMargin: 12
            text: bar.active ? (DesktopEntries.byId(bar.active.appId)?.name ?? bar.active.appId) : "Masaüstü"
            color: Theme.text
            font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
            elide: Text.ElideRight
            Layout.maximumWidth: 320
        }
        Text {
            Layout.leftMargin: 14
            visible: bar.active !== null && bar.active.title !== ""
            text: bar.active ? bar.active.title : ""
            color: Theme.textDim
            font { family: Theme.font; pixelSize: 13 }
            elide: Text.ElideRight
            Layout.maximumWidth: 420
        }

        Item { Layout.fillWidth: true }

        IconButton {
            visible: Sys.updates > 0
            icon: "cloud-download"; size: 30; iconSize: 16
            label: String(Sys.updates)
            tint: Theme.accent
            onClicked: Quickshell.execDetached(["ayaz-settings", "updates"])
        }
        IconButton {
            icon: "moon"; label: "Odak"; size: 30; iconSize: 15
            active: Shell.focusMode
            onClicked: Shell.focusMode = !Shell.focusMode
        }
        IconButton {
            size: 30; iconSize: 16
            icon: Sys.netKind === "none" ? "wifi-off" : "wifi"
            onClicked: Shell.controlOpen = !Shell.controlOpen
        }
        IconButton {
            size: 30; iconSize: 16
            icon: Sys.muted || Sys.volume === 0 ? "volume-x" : "volume-2"
            onClicked: Shell.controlOpen = !Shell.controlOpen
        }
        IconButton {
            visible: Sys.hasBattery
            size: 30; iconSize: 17
            icon: Sys.charging ? "battery-charging" : "battery-medium"
            label: "%" + Sys.batteryPercent
            onClicked: Shell.controlOpen = !Shell.controlOpen
        }
        Text {
            Layout.leftMargin: 14
            text: Sys.dateShort + "  " + Sys.time
            color: Theme.text
            font { family: Theme.font; pixelSize: 14; weight: Font.Medium; features: { "tnum": 1 } }
        }
        IconButton {
            Layout.leftMargin: 8
            icon: "sliders-horizontal"; size: 30; iconSize: 17
            active: Shell.controlOpen
            onClicked: { Shell.startOpen = false; Shell.controlOpen = !Shell.controlOpen; }
        }
    }
}
