import QtQuick
import AyazOS.UI
import AyazOS.Native
import "../components"

Page {
    id: pg
    title: "Kullanıcılar ve Güvenlik"
    subtitle: "Hesabın, parolan ve ekran kilidi."

    property string user: Fs.home.split("/").pop()
    property string fullName: ""
    property bool changing: false

    Component.onCompleted: {
        Sh.sh("id -un; getent passwd \"$(id -un)\" | cut -d: -f5 | cut -d, -f1", (c, out) => {
            const l = out.split("\n");
            if (l[0]) user = l[0];
            fullName = l[1] || "";
        });
    }

    function changePass() {
        Sh.ask({ title: "Parolayı değiştir", message: "Mevcut ve yeni parolanı gir.",
                 fields: [{ placeholder: "Mevcut parola", password: true }, { placeholder: "Yeni parola", password: true }, { placeholder: "Yeni parola (tekrar)", password: true }],
                 ok: "Değiştir" }, v => {
            if (!v[0] || !v[1]) { Sh.toast("Parola boş olamaz"); return; }
            if (v[1] !== v[2]) { Sh.toast("Yeni parolalar eşleşmiyor"); return; }
            changing = true;
            Sh.run(["sh", "-c", "printf '%s\\n%s\\n%s\\n' \"$1\" \"$2\" \"$2\" | passwd", "_", v[0], v[1]], (c, out, err) => {
                changing = false;
                Sh.toast(c === 0 ? "Parola değiştirildi" : "Parola değiştirilemedi");
            });
        });
    }

    Card {
        Item {
            width: parent.width; height: 110
            Rectangle {
                id: av
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 64; radius: 32
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(Sh.accent, 1.15) }
                    GradientStop { position: 1; color: Sh.accent }
                }
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.3)
                Text { anchors.centerIn: parent; text: pg.user ? pg.user[0].toUpperCase() : "?"; color: Theme.accentInk; font { family: Theme.font; pixelSize: 28; weight: Font.Medium } }
            }
            Column {
                anchors { left: av.right; leftMargin: 20; verticalCenter: parent.verticalCenter }
                spacing: 4
                Text { text: pg.fullName || pg.user; color: Theme.text; font { family: Theme.font; pixelSize: 20; weight: Font.Medium } }
                Text { text: "@" + pg.user + " · Yönetici"; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } }
            }
        }
    }

    Card {
        heading: "Güvenlik"
        SRow {
            label: "Parola"
            sub: "Hesabının oturum açma parolası"
            icon: "lock"
            PillButton { text: "Değiştir"; busy: pg.changing; onClicked: pg.changePass() }
        }
        SRow {
            label: "Otomatik kilit"
            sub: "Hareketsiz kalınca ekranı kilitle"
            icon: "shield-check"
            Dropdown {
                model: [{ label: "1 dakika", value: 60 }, { label: "5 dakika", value: 300 }, { label: "15 dakika", value: 900 }, { label: "30 dakika", value: 1800 }, { label: "Hiçbir zaman", value: 0 }]
                current: Sh.get("lockDelay", 300)
                onPicked: v => Sh.set("lockDelay", v)
            }
        }
        SRow {
            label: "Ekranı şimdi kilitle"
            icon: "power"
            PillButton { text: "Kilitle"; onClicked: Sh.fire(["qs", "-c", "ayazos", "ipc", "call", "lock", "lock"]) }
        }
    }
}
