import QtQuick
import AyazOS.UI

// Düğme: birincil (vurgu rengi), ikincil (cam) ya da tehlike
Rectangle {
    id: b
    property string text
    property string kind: "secondary"   // primary | secondary | danger
    property bool busy: false
    property bool enabled2: true
    signal clicked()
    implicitWidth: lbl.implicitWidth + 36
    width: implicitWidth; height: 36
    radius: 11
    opacity: enabled2 && !busy ? 1 : 0.5
    color: kind === "primary" ? Sh.accent
         : kind === "danger" ? Qt.rgba(242 / 255, 119 / 255, 122 / 255, ma.containsMouse ? 0.24 : 0.14)
         : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
    border.width: 1
    border.color: kind === "primary" ? Qt.rgba(1, 1, 1, 0.3) : kind === "danger" ? Qt.rgba(242 / 255, 119 / 255, 122 / 255, 0.4) : Theme.strokeHi
    scale: ma.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Theme.dFast } }
    Behavior on color { ColorAnimation { duration: Theme.dFast } }
    Text {
        id: lbl
        anchors.centerIn: parent
        text: b.busy ? "Bekleyin…" : b.text
        color: b.kind === "primary" ? Theme.accentInk : b.kind === "danger" ? Theme.danger : Theme.text
        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (b.enabled2 && !b.busy) b.clicked()
    }
}
