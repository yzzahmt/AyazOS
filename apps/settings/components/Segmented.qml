import QtQuick
import AyazOS.UI

// Segmentli seçici; seçim kaydırmalı bir hap ile gösterilir.
Item {
    id: seg
    property var model: []          // [{label, value}] ya da düz metin
    property int currentIndex: 0
    property int segWidth: 96
    signal picked(int index, var value)

    function lbl(m) { return typeof m === "string" ? m : m.label; }
    width: model.length * segWidth + 6
    height: 36

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.25)
        border.width: 1
        border.color: Theme.stroke
    }
    Rectangle {
        y: 3; height: parent.height - 6
        width: seg.segWidth
        radius: 9
        x: 3 + seg.currentIndex * seg.segWidth
        color: Qt.rgba(1, 1, 1, 0.13)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        visible: seg.currentIndex >= 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
    }
    Row {
        x: 3
        Repeater {
            model: seg.model
            Item {
                required property var modelData
                required property int index
                width: seg.segWidth; height: seg.height
                Text {
                    anchors.centerIn: parent
                    text: seg.lbl(modelData)
                    color: index === seg.currentIndex ? Theme.text : Theme.textDim
                    font { family: Theme.font; pixelSize: 13; weight: index === seg.currentIndex ? Font.Medium : Font.Normal }
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        seg.currentIndex = index;
                        seg.picked(index, typeof modelData === "string" ? modelData : modelData.value);
                    }
                }
            }
        }
    }
}
