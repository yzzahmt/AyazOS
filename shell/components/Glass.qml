import QtQuick
import "../services"

// Cam yüzey: yarı saydam koyu dolgu, ince açık kenar ve üstte hafif parıltı.
// Bulanıklığı bileşik yönetici (Wayfire blur) sağlar.
Rectangle {
    id: root
    property bool light: false
    property bool sheen: true
    radius: Theme.rCard
    color: light ? Theme.glassHi : Theme.glass
    border.width: 1
    border.color: Theme.stroke

    Rectangle {
        visible: root.sheen
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }
}
