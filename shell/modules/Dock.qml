import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../components"

// Sağdaki dikey dock. Üstte logo (başlat), ortada sabit uygulamalar, altta çöp kutusu.
PanelWindow {
    id: dock
    anchors { right: true; top: true; bottom: true }
    implicitWidth: 112
    exclusiveZone: 100
    color: "transparent"
    WlrLayershell.namespace: "ayaz-dock"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: panel }

    // Dock'ta görünen her uygulamanın açık pencere sayısı (appId ile eşleşir).
    function runningCount(id) {
        let n = 0;
        for (const t of ToplevelManager.toplevels.values)
            if (t.appId === id || t.appId.toLowerCase() === id.toLowerCase()) n++;
        return n;
    }
    function activate(id) {
        for (const t of ToplevelManager.toplevels.values)
            if (t.appId === id) { t.activate(); return true; }
        return false;
    }

    // Logo düğmesinin ekrandaki konumu: başlat menüsü buradan açılır.
    // (Dock penceresi üst çubuğun altından başlar: 44 px.)
    readonly property point startOrigin: Qt.point((screen ? screen.width : 1920) - 32 - panel.width / 2,
                                                  44 + panel.y + column.y + logo.y + logo.height / 2)

    Glass {
        id: panel
        anchors { right: parent.right; rightMargin: 32; verticalCenter: parent.verticalCenter }
        width: 80
        height: column.implicitHeight + 36
        radius: Theme.rDock

        Column {
            id: column
            anchors { top: parent.top; topMargin: 18; horizontalCenter: parent.horizontalCenter }
            spacing: 10

            Rectangle { width: 36; height: 1; color: Theme.stroke; anchors.horizontalCenter: parent.horizontalCenter }

            DockTile {
                id: logo
                tooltip: "Başlat"
                active: Shell.startOpen
                Image {
                    anchors.centerIn: parent
                    width: 30; height: 30
                    sourceSize: Qt.size(60, 60)
                    source: Qt.resolvedUrl("../assets/ayazos-mark.svg")
                    rotation: Shell.startOpen ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.OutBack } }
                }
                onClicked: Shell.toggleStart()
            }

            Repeater {
                model: Shell.pinned
                DockTile {
                    required property var modelData
                    readonly property int count: dock.runningCount(modelData.id)
                    tooltip: modelData.name
                    running: count > 0
                    active: ToplevelManager.activeToplevel?.appId === modelData.id
                    Icon { anchors.centerIn: parent; name: modelData.icon; size: 22 }
                    onClicked: if (!dock.activate(modelData.id)) Shell.launch(modelData.id)
                }
            }

            Rectangle { width: 36; height: 1; color: Theme.stroke; anchors.horizontalCenter: parent.horizontalCenter }

            DockTile {
                tooltip: "Çöp Kutusu"
                Icon { anchors.centerIn: parent; name: "trash-2"; size: 22 }
                onClicked: Quickshell.execDetached(["ayaz-files", "trash:///"])
            }
        }
    }

    component DockTile: Item {
        id: tile
        property string tooltip
        property bool running: false
        property bool active: false
        signal clicked()
        width: 60; height: 60
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

        Rectangle {
            id: face
            anchors.fill: parent
            radius: 16
            scale: tileMouse.pressed ? 0.9 : (tileMouse.containsMouse ? 1.08 : 1)
            Behavior on scale { SpringAnimation { spring: 4; damping: 0.32 } }
            gradient: Gradient {
                GradientStop { position: 0; color: tile.active ? "#3A4C6E" : "#2A3242" }
                GradientStop { position: 1; color: tile.active ? "#2C3A56" : "#1C222E" }
            }
            border.width: 1
            border.color: tile.active ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.45) : Theme.strokeHi
        }
        // İçerik (simge) yüzle birlikte büyür.
        default property alias content: holder.data
        Item { id: holder; anchors.fill: parent; scale: face.scale }

        // Çalışan uygulama göstergesi: sol tarafta küçük nokta.
        Rectangle {
            width: 5; height: tile.active ? 14 : 5; radius: 2.5
            color: Theme.accent
            opacity: tile.running ? 1 : 0
            anchors { right: parent.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            Behavior on height { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.dNormal } }
        }

        MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; onClicked: tile.clicked() }

        // Etiket: dock'un soluna açılır.
        Glass {
            visible: opacity > 0
            opacity: tileMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dFast } }
            x: -width - 18
            anchors.verticalCenter: parent.verticalCenter
            width: tipText.implicitWidth + 22; height: 30; radius: 10
            color: Theme.glassSolid
            Text {
                id: tipText; anchors.centerIn: parent; text: tile.tooltip
                color: Theme.text; font { family: Theme.font; pixelSize: 12 }
            }
        }
    }
}
