import QtQuick
import AyazOS.UI

// Tuş görseli
Rectangle {
    property string label
    property color accent: Theme.accent
    implicitWidth: Math.max(34, t.implicitWidth + 20)
    width: implicitWidth; height: 32; radius: 9
    color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1; border.color: Theme.strokeHi
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 } height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.10) }
    Text {
        id: t
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: parent.label
        color: Theme.text
        font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
    }
}
