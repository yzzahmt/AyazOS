import QtQuick
import AyazOS.UI

// Özel kaydırıcı
Item {
    id: s
    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    property bool showValue: false
    property string suffix: ""
    property int decimals: 0
    signal moved(real value)
    signal released(real value)

    width: 220; height: 28
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    Rectangle {
        id: track
        anchors { left: parent.left; right: valueText.visible ? valueText.left : parent.right; rightMargin: valueText.visible ? 12 : 0; verticalCenter: parent.verticalCenter }
        height: 6; radius: 3
        color: Qt.rgba(1, 1, 1, 0.12)
        Rectangle {
            width: s.frac * parent.width; height: parent.height; radius: 3
            color: Sh.accent
        }
        Rectangle {
            id: handle
            width: ma.pressed ? 22 : 18; height: width; radius: width / 2
            x: s.frac * (track.width - 18) + (18 - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "#F2F5FA"
            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.2)
            Behavior on width { NumberAnimation { duration: 100 } }
        }
        MouseArea {
            id: ma
            anchors { fill: parent; topMargin: -12; bottomMargin: -12 }
            cursorShape: Qt.PointingHandCursor
            function upd(mx) {
                let f = Math.max(0, Math.min(1, (mx - 9) / (track.width - 18)));
                let v = s.from + f * (s.to - s.from);
                if (s.stepSize > 0) v = Math.round(v / s.stepSize) * s.stepSize;
                s.value = v;
                s.moved(v);
            }
            onPressed: mouse => upd(mouse.x)
            onPositionChanged: mouse => { if (pressed) upd(mouse.x); }
            onReleased: s.released(s.value)
        }
    }
    Text {
        id: valueText
        visible: s.showValue
        width: visible ? 52 : 0
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        horizontalAlignment: Text.AlignRight
        text: s.value.toFixed(s.decimals) + s.suffix
        color: Theme.textDim
        font { family: Theme.font; pixelSize: 13 }
    }
}
