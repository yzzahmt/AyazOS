import QtQuick
import AyazOS.UI

// Renk örneği
Item {
    id: sw
    property color swatch
    property bool selected: false
    signal clicked()
    width: 36; height: 36
    Rectangle {
        anchors.centerIn: parent
        width: sw.selected ? 36 : 30; height: width; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: sw.selected ? sw.swatch : "transparent"
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 8; height: width; radius: width / 2
            color: sw.swatch
            scale: ma.containsMouse ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: Theme.dFast } }
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sw.clicked() }
}
