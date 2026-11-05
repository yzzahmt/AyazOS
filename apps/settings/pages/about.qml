import QtQuick
import AyazOS.UI
import AyazOS.Native
import "../components"

Page {
    id: pg
    title: "Hakkında"
    subtitle: "Bu bilgisayar hakkında."

    property var info: ({})
    property string host: ""
    property string logo: "/usr/share/pixmaps/ayazos.svg"

    function load() {
        const script = "echo \"os=$(. /etc/os-release; echo $PRETTY_NAME)\"; echo \"ver=$(cat /usr/share/ayazos/VERSION 2>/dev/null || cat $HOME/AyazOS/VERSION 2>/dev/null)\";" +
            "echo \"cpu=$(lscpu 2>/dev/null | sed -n 's/^Model name:[ \\t]*//p' | head -1)\"; echo \"cores=$(nproc 2>/dev/null)\";" +
            "echo \"gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/^[^:]*:[^:]*: //')\";" +
            "echo \"ram=$(awk '/MemTotal/ {print $2}' /proc/meminfo)\"; echo \"kernel=$(uname -r)\"; echo \"host=$(hostname)\"";
        Sh.sh(script, (c, out) => {
            const o = {};
            out.split("\n").forEach(l => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); });
            info = o; host = o.host || "";
        });
    }
    Component.onCompleted: {
        load();
        if (!Fs.exists(logo)) logo = Fs.home + "/AyazOS/branding/logo/ayazos-mark.svg";
    }
    readonly property var st: Fs.storage("/")
    function na(v) { return v && v !== "-" ? v : "Kullanılamıyor"; }

    Card {
        Item {
            width: parent.width; height: 220
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Sh.accent.r, Sh.accent.g, Sh.accent.b, 0.16) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            Image {
                id: lg
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 30 }
                width: 96; height: 96
                source: Fs.exists(pg.logo) ? "file://" + pg.logo : ""
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; top: lg.bottom; topMargin: 14 }
                spacing: 4
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "AyazOS"; color: Theme.text; font { family: Theme.font; pixelSize: 26; weight: Font.Medium } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sürüm " + (pg.info.ver || "0.1.0") + " · " + (pg.info.os || ""); color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } }
            }
        }
    }

    Card {
        heading: "Cihaz"
        SRow {
            label: "Bilgisayar adı"
            icon: "monitor"
            Row {
                spacing: 12
                Text { anchors.verticalCenter: parent.verticalCenter; text: pg.host; color: Theme.textDim; font { family: Theme.font; pixelSize: 14 } }
                PillButton {
                    text: "Yeniden adlandır"
                    onClicked: Sh.ask({ title: "Bilgisayar adı", message: "Yeni ad (harf, rakam ve tire).", fields: [{ placeholder: pg.host }], ok: "Kaydet" }, v => {
                        const n = v[0].trim();
                        if (!/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(n)) { Sh.toast("Geçersiz ad"); return; }
                        Sh.run(["pkexec", "hostnamectl", "set-hostname", n], c => { Sh.toast(c === 0 ? "Ad değiştirildi" : "Ad değiştirilemedi"); pg.load(); });
                    })
                }
            }
        }
        SRow { label: "İşlemci"; icon: "cpu"; Text { text: (pg.info.cpu && pg.info.cpu !== "-" ? pg.info.cpu + " · " : "") + (pg.info.cores ? pg.info.cores + " çekirdek" : "Kullanılamıyor"); color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } } }
        SRow { label: "Ekran kartı"; icon: "layers"; Text { text: pg.na(pg.info.gpu); color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } } }
        SRow { label: "Bellek"; icon: "activity"; Text { text: pg.info.ram ? (parseInt(pg.info.ram) / 1048576).toFixed(1).replace(".", ",") + " GB" : "Kullanılamıyor"; color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } } }
        SRow { label: "Depolama"; icon: "hard-drive"; Text { text: Fs.formatSize(pg.st.free) + " boş / " + Fs.formatSize(pg.st.total); color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } } }
        SRow { label: "Çekirdek"; icon: "terminal"; Text { text: pg.na(pg.info.kernel); color: Theme.textDim; font { family: Theme.font; pixelSize: 13 } } }
    }
}
