import QtQuick
import AyazOS.UI

// Kart satırı: solda etiket, sağda denetim.
Item {
    id: row
    property string label
    property string sub: ""
    property string icon: ""
    property bool clickable: false
    property bool highlight: false
    default property alias control: slot.data
    signal clicked()

    width: parent ? parent.width : 400
    implicitHeight: Math.max(58, texts.implicitHeight + 24)

    Rectangle {
        anchors.fill: parent
        color: rowMouse.containsMouse && row.clickable ? Qt.rgba(1, 1, 1, 0.04) : (row.highlight ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }
    Rectangle { visible: row.y > 0; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 18 } height: 1; color: Theme.stroke }

    Icon {
        id: ic
        visible: row.icon !== ""
        name: row.icon !== "" ? row.icon : "info"
        size: 20
        color: Theme.textDim
        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
    }
    Column {
        id: texts
        anchors { left: parent.left; leftMargin: row.icon !== "" ? 54 : 18; right: slot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 3
        Text {
            width: parent.width
            text: row.label
            elide: Text.ElideRight
            color: Theme.text
            font { family: Theme.font; pixelSize: 14 }
        }
        Text {
            visible: row.sub !== ""
            width: parent.width
            text: row.sub
            elide: Text.ElideRight
            color: Theme.textDim
            font { family: Theme.font; pixelSize: 12 }
        }
    }
    Item {
        id: slot
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
    }
    MouseArea {
        id: rowMouse
        anchors.fill: parent
        enabled: row.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
        z: -1
    }
}
