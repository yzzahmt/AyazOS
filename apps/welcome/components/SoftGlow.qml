import QtQuick

// Yumuşak, kenarsız ışıma (radyal gradyan)
Canvas {
    id: g
    property color color: "#A9C1F2"
    property real strength: 0.2
    onColorChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const r = width / 2;
        const gr = c.createRadialGradient(r, r, 0, r, r, r);
        const s = strength;
        gr.addColorStop(0, Qt.rgba(color.r, color.g, color.b, s));
        gr.addColorStop(0.4, Qt.rgba(color.r, color.g, color.b, s * 0.45));
        gr.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0));
        c.fillStyle = gr;
        c.fillRect(0, 0, width, height);
    }
}
