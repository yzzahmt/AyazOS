import QtQuick
import "../services"

// Yuvarlatılmış simge düğmesi; üzerine gelince hafif parlar, basınca küçülür.
Item {
    id: root
    property string icon
    property int size: 36
    property int iconSize: 18
    property string label: ""
    property bool active: false
    property color tint: Theme.text
    signal clicked()

    implicitWidth: label ? row.implicitWidth + 20 : size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: Theme.rButton
        color: root.active ? Theme.selected : (mouse.containsMouse ? Theme.hover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        scale: mouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dFast; easing.type: Easing.OutCubic } }
        Icon { name: root.icon; size: root.iconSize; color: root.tint; anchors.verticalCenter: parent.verticalCenter }
        Text {
            visible: root.label !== ""
            text: root.label
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: Theme.fsBody
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
