import QtQuick
import AyazOS.UI

// Yaylı anahtar
Item {
    id: t
    property bool checked: false
    property bool enabled2: true
    signal toggled(bool value)
    width: 48; height: 28
    opacity: enabled2 ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: t.checked ? Sh.accent : Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: t.checked ? Qt.rgba(1, 1, 1, 0.25) : Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.dNormal } }
    }
    Rectangle {
        id: knob
        width: knobMouse.pressed ? 26 : 22
        height: 22
        radius: 11
        y: 3
        x: t.checked ? t.width - width - 3 : 3
        color: t.checked ? Theme.accentInk : "#E8EDF5"
        Behavior on x { SpringAnimation { spring: 5.5; damping: 0.32; mass: 0.7 } }
        Behavior on width { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: Theme.dNormal } }
    }
    MouseArea {
        id: knobMouse
        anchors.fill: parent
        enabled: t.enabled2
        cursorShape: Qt.PointingHandCursor
        onClicked: { t.checked = !t.checked; t.toggled(t.checked); }
    }
}
