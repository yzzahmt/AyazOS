import QtQuick
import AyazOS.UI

// Düğme: primary (vurgu) | secondary (cam)
Rectangle {
    id: b
    property string text
    property string kind: "secondary"
    property color accent: Theme.accent
    property bool active: true
    signal clicked()
    implicitWidth: lbl.implicitWidth + 44
    width: implicitWidth; height: 42
    radius: 14
    opacity: active ? 1 : 0.4
    color: kind === "primary" ? accent
         : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
    border.width: 1
    border.color: kind === "primary" ? Qt.rgba(1, 1, 1, 0.35) : Theme.strokeHi
    scale: ma.pressed ? 0.96 : (ma.containsMouse ? 1.03 : 1)
    Behavior on scale { NumberAnimation { duration: Theme.dFast } }
    Behavior on color { ColorAnimation { duration: Theme.dFast } }
    Text {
        id: lbl
        anchors.centerIn: parent
        text: b.text
        color: b.kind === "primary" ? Theme.accentInk : Theme.text
        font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (b.active) b.clicked()
    }
}
