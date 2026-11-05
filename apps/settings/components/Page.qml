import QtQuick
import AyazOS.UI

// Sayfa iskeleti: büyük başlık + alt başlık + kaydırılabilir içerik.
Flickable {
    id: page
    property string title
    property string subtitle
    default property alias content: col.data
    signal activated()

    contentWidth: width
    contentHeight: col.implicitHeight + 90
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
        id: col
        x: 40
        y: 36
        width: Math.min(page.width - 80, 760)
        spacing: 22

        Column {
            width: parent.width
            spacing: 6
            bottomPadding: 6
            Text { text: page.title; color: Theme.text; font { family: Theme.font; pixelSize: 30; weight: Font.Medium } }
            Text { text: page.subtitle; color: Theme.textDim; font { family: Theme.font; pixelSize: 14 } }
        }
    }
    Component.onCompleted: activated()
}
