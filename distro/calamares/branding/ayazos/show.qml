import QtQuick
import calamares.slideshow 1.0

// Kurulum sırasında gösterilen tanıtım.
Presentation {
    id: presentation
    function nextSlide() { presentation.goToNextSlide(); }
    Timer { interval: 7000; running: presentation.activatedInCalamares; repeat: true; onTriggered: nextSlide() }

    Repeater {
        model: [
            { t: "Kendine alan aç.", s: "AyazOS kuruluyor. Birkaç dakika sürecek." },
            { t: "Hızlı ve hafif", s: "Snap yok, gereksiz servis yok. Uygulamalar anında açılır." },
            { t: "Her şey tek yerde", s: "Yazılım Merkezi, sürücüler ve güncellemeler terminal olmadan." },
            { t: "Oyuna hazır", s: "Steam, Proton ve oyun modu kurulumla birlikte gelir." },
            { t: "Windows uygulamaları", s: ".exe dosyasına çift tıklaman yeterli." }
        ]
        Slide {
            required property var modelData
            Rectangle { anchors.fill: parent; color: "#0A0E15" }
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: "#E8EDF5"; font.pixelSize: 34; font.family: "Inter"; font.weight: Font.Light }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.s; color: "#8A94A6"; font.pixelSize: 15; font.family: "Inter" }
            }
        }
    }
}
