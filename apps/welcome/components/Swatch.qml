import QtQuick
import AyazOS.UI

Item {
    id: sw
    property color swatch
    property bool selected: false
    signal clicked()
    width: 44; height: 44
    Rectangle {
        anchors.centerIn: parent
        width: sw.selected ? 44 : 36; height: width; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: sw.selected ? sw.swatch : "transparent"
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 10; height: width; radius: width / 2
            color: sw.swatch
            scale: ma.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: Theme.dFast } }
            Icon { anchors.centerIn: parent; name: "check"; size: 16; color: Theme.accentInk; opacity: sw.selected ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 160 } } }
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sw.clicked() }
}
