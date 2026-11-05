import QtQuick
import AyazOS.UI

// Açılır liste; menü ana pencerenin katmanında çizilir (kırpılmaz).
Rectangle {
    id: dd
    property var model: []          // [{label, value}]
    property var current: null      // seçili value
    property string placeholder: "Seç"
    property int minWidth: 150
    signal picked(var value)

    function labelOf(v) {
        for (let i = 0; i < model.length; i++) if (model[i].value === v) return model[i].label;
        return placeholder;
    }
    implicitWidth: Math.max(minWidth, txt.implicitWidth + 56)
    implicitHeight: 36
    width: implicitWidth; height: 36
    radius: 11
    color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    border.color: Theme.strokeHi
    Behavior on color { ColorAnimation { duration: Theme.dFast } }

    Text {
        id: txt
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        text: dd.labelOf(dd.current)
        color: Theme.text
        font { family: Theme.font; pixelSize: 13 }
    }
    Icon { name: "chevron-down"; size: 15; color: Theme.textDim; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Sh.menu(dd, dd.model, dd.current, v => { dd.current = v; dd.picked(v); })
    }
}
