import QtQuick
import AyazOS.UI

// Gruplanmış yuvarlak kart; satırlar arası ince çizgi SRow tarafından çizilir.
Item {
    id: card
    property string heading: ""
    property string footnote: ""
    default property alias rows: inner.data
    width: parent ? parent.width : 400
    implicitHeight: head.height + body.height + foot.height

    Text {
        id: head
        visible: card.heading !== ""
        height: visible ? 28 : 0
        leftPadding: 6
        text: card.heading.toUpperCase()
        color: Theme.textDim
        font { family: Theme.font; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.2 }
    }
    Rectangle {
        id: body
        anchors { top: head.bottom; left: parent.left; right: parent.right }
        height: inner.implicitHeight
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Theme.stroke
        clip: true
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.035) }
                GradientStop { position: 0.5; color: "transparent" }
            }
        }
        Column { id: inner; width: parent.width }
    }
    Text {
        id: foot
        anchors { top: body.bottom; left: parent.left; right: parent.right; leftMargin: 6; topMargin: 8 }
        visible: card.footnote !== ""
        height: visible ? implicitHeight + 8 : 0
        text: card.footnote
        wrapMode: Text.Wrap
        color: Theme.textFaint
        font { family: Theme.font; pixelSize: 12 }
    }
}
