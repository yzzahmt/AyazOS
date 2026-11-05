import QtQuick
import QtQuick.Effects
import "../services"

// Lucide çizgi simgesi; istenirse yeniden renklendirilir.
Item {
    id: root
    property string name
    property int size: 20
    property color color: Theme.text
    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? Theme.icon(root.name) : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        visible: root.color === Theme.text
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: !img.visible
        colorization: 1.0
        colorizationColor: root.color
        brightness: root.color.hslLightness > 0.5 ? 0.0 : -0.9
    }
}
