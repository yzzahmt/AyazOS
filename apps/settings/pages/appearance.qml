import QtQuick
import AyazOS.UI
import AyazOS.Native
import "../components"

Page {
    id: pg
    title: "Görünüm"
    subtitle: "Masaüstünü kendine göre ayarla."

    readonly property string defaultWp: "/usr/share/backgrounds/ayazos/default.jpg"
    property var wallpapers: []
    readonly property string wp: Sh.get("wallpaper", defaultWp)
    readonly property var accents: ["#A9C1F2", "#8B5CF6", "#5EC8C0", "#F2A0C0", "#F2B66D", "#7BD88F"]

    function scan() {
        const dirs = ["/usr/share/backgrounds/ayazos", Fs.userDir("PICTURES"), Fs.home + "/Resimler", Fs.home + "/Pictures"];
        const seen = {};
        const out = [];
        dirs.forEach(d => {
            if (!d || !Fs.exists(d)) return;
            Array.from(Fs.list(d, false, "name", false)).forEach(it => {
                if (it.dir || seen[it.path]) return;
                if (/\.(jpe?g|png|webp)$/i.test(it.name)) { seen[it.path] = true; out.push(it); }
            });
        });
        wallpapers = out;
    }
    Component.onCompleted: scan()

    // Canlı önizleme
    Item {
        width: parent.width; height: 210
        Rectangle {
            anchors.fill: parent; radius: 18
            color: Theme.base
            border.width: 1; border.color: Theme.strokeHi
            clip: true
            Image {
                anchors.fill: parent
                source: pg.wp ? "file://" + pg.wp : ""
                sourceSize.width: 900
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }
            Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.4; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) } } }
            // sahte pencere
            Rectangle {
                x: 70; y: 34; width: 250; height: 120; radius: 12
                color: Qt.rgba(13 / 255, 17 / 255, 25 / 255, 0.78)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                Rectangle { x: 14; y: 16; width: 70; height: 8; radius: 4; color: Sh.accent }
                Repeater {
                    model: 3
                    Rectangle { required property int index; x: 14; y: 40 + index * 22; width: 150 - index * 30; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.18) }
                }
                Rectangle { x: parent.width - 54; y: parent.height - 38; width: 38; height: 22; radius: 7; color: Sh.accent }
            }
            // sahte dock
            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
                width: 230; height: 34; radius: 14
                color: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.7)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                Row {
                    anchors.centerIn: parent; spacing: 12
                    Repeater {
                        model: 6
                        Rectangle { required property int index; width: 20; height: 20; radius: 6; color: index === 1 ? Sh.accent : Qt.rgba(1, 1, 1, 0.22) }
                    }
                }
            }
        }
    }

    Card {
        heading: "Duvar kağıdı"
        Item {
            width: parent.width
            height: grid.height + 36
            Flow {
                id: grid
                x: 18; y: 18
                width: parent.width - 36
                spacing: 12
                Repeater {
                    model: pg.wallpapers
                    Item {
                        required property var modelData
                        readonly property bool sel: modelData.path === pg.wp
                        width: (grid.width - 24) / 3; height: width * 0.62
                        Rectangle {
                            anchors.fill: parent; radius: 12
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: sel ? 2 : 1
                            border.color: sel ? Sh.accent : Theme.stroke
                            scale: wm.containsMouse && !sel ? 1.025 : 1
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            clip: true
                            Image {
                                anchors { fill: parent; margins: 3 }
                                source: "file://" + modelData.path
                                sourceSize.width: 360
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Rectangle {
                                visible: sel
                                width: 24; height: 24; radius: 12; color: Sh.accent
                                anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                                Icon { anchors.centerIn: parent; name: "check"; size: 14; color: Theme.accentInk }
                            }
                            MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Sh.set("wallpaper", modelData.path) }
                        }
                    }
                }
            }
            Text {
                visible: pg.wallpapers.length === 0
                anchors.centerIn: parent
                text: "Duvar kağıdı bulunamadı"
                color: Theme.textDim
                font { family: Theme.font; pixelSize: 13 }
            }
        }
        SRow {
            label: "Resimler klasörü"
            sub: "Görselleri Resimler klasörüne koyarsan burada görünür"
            icon: "image"
            PillButton { text: "Yenile"; onClicked: pg.scan() }
        }
    }

    Card {
        heading: "Vurgu rengi"
        SRow {
            label: "Renk"
            sub: "Düğmeler, seçimler ve kaydırıcılar"
            Row {
                spacing: 4
                Repeater {
                    model: pg.accents
                    Swatch {
                        required property string modelData
                        swatch: modelData
                        selected: Sh.accent.toString().toLowerCase() === modelData.toLowerCase()
                        onClicked: Sh.set("accent", modelData)
                    }
                }
            }
        }
    }

    Card {
        heading: "Efektler"
        footnote: "Pil dostu kip, canlı bulanıklık yerine hazır bulanık duvar kağıdı kullanır."
        SRow {
            label: "Cam efekti"
            sub: "Pencerelerdeki bulanıklık kalitesi"
            icon: "layers"
            Segmented {
                segWidth: 92
                model: [{ label: "Yüksek", value: "high" }, { label: "Dengeli", value: "balanced" }, { label: "Pil dostu", value: "battery" }]
                currentIndex: Math.max(0, ["high", "balanced", "battery"].indexOf(Sh.get("glass", "high")))
                onPicked: (i, v) => Sh.set("glass", v)
            }
        }
        SRow {
            label: "Animasyonlar"
            sub: "Pencere açma, kapama ve geçiş efektleri"
            icon: "sparkles"
            Toggle { checked: Sh.get("animations", true); onToggled: v => Sh.set("animations", v) }
        }
    }
}
