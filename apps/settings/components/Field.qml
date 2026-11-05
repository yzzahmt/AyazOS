import QtQuick
import AyazOS.UI

// Metin alanı
Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property alias input: input
    signal accepted()
    width: 240; height: 40
    radius: 11
    color: Qt.rgba(0, 0, 0, 0.25)
    border.width: 1
    border.color: input.activeFocus ? Qt.rgba(Sh.accent.r, Sh.accent.g, Sh.accent.b, 0.6) : Theme.strokeHi
    Behavior on border.color { ColorAnimation { duration: Theme.dFast } }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        clip: true
        selectByMouse: true
        selectionColor: Sh.accent
        selectedTextColor: Theme.accentInk
        echoMode: f.password ? TextInput.Password : TextInput.Normal
        font { family: Theme.font; pixelSize: 14 }
        onAccepted: f.accepted()
        Text {
            visible: !input.text && !input.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: f.placeholder
            color: Theme.textFaint
            font: input.font
        }
    }
}
