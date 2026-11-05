pragma Singleton
import QtQuick

// AyazOS tasarım belirteçleri. Değerler docs/ARCHITECTURE.md ile aynıdır.
QtObject {
    readonly property color base: "#0A0E15"
    readonly property color glass: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.78)
    readonly property color glassHi: Qt.rgba(36 / 255, 44 / 255, 58 / 255, 0.70)
    readonly property color glassSolid: "#121822"
    readonly property color stroke: Qt.rgba(1, 1, 1, 0.08)
    readonly property color strokeHi: Qt.rgba(1, 1, 1, 0.16)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.06)
    readonly property color selected: Qt.rgba(120 / 255, 150 / 255, 200 / 255, 0.16)
    readonly property color text: "#E8EDF5"
    readonly property color textDim: "#8A94A6"
    readonly property color textFaint: "#5E6879"
    readonly property color accent: "#A9C1F2"
    readonly property color accentInk: "#0E1626"
    readonly property color violet: "#8B5CF6"
    readonly property color danger: "#F2777A"

    readonly property int rWindow: 22
    readonly property int rDock: 26
    readonly property int rCard: 14
    readonly property int rButton: 12

    readonly property string font: "Inter"
    readonly property int fsSmall: 11
    readonly property int fsBody: 13
    readonly property int fsTitle: 15

    readonly property int dFast: 140
    readonly property int dNormal: 220
    readonly property int dSlow: 420

    // Düşük güç kipinde canlı bulanıklık yerine hazır bulanık duvar kağıdı kullanılır.
    property bool lowPower: false

    function icon(name) {
        return Qt.resolvedUrl("../assets/icons/" + name + ".svg");
    }
}
