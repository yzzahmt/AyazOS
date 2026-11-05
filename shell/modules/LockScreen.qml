import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import "../services"
import "../components"

// Kilit ekranı: bulanık duvar kağıdı, büyük saat, müzik, pil ve parola.
// Kilit açılırken bulanıklık çözülür ve içerik öne doğru dağılır.
Scope {
    id: root
    property bool unlocking: false
    property string wallpaper: "/usr/share/backgrounds/ayazos/default.jpg"

    function lockNow() { unlocking = false; lock.locked = true; }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lockNow(); }
    }

    PamContext {
        id: pam
        config: "ayazos-lock"
        property string password: ""
        onPamMessage: if (responseRequired) respond(password)
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocking = true;
                unlockTimer.start();
            } else {
                pam.password = "";
                failed();
            }
        }
        signal failed()
    }
    Timer { id: unlockTimer; interval: 520; onTriggered: lock.locked = false }

    WlSessionLock {
        id: lock

        WlSessionLockSurface {
            id: surface
            color: Theme.base

            readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + root.wallpaper
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blurMax: 64
                blur: root.unlocking ? 0 : 1
                brightness: root.unlocking ? 0 : -0.18
                saturation: 0.1
                scale: root.unlocking ? 1.0 : 1.06
                Behavior on blur { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on brightness { NumberAnimation { duration: 500 } }
                Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            }

            Item {
                id: stage
                anchors.fill: parent
                opacity: root.unlocking ? 0 : 1
                scale: root.unlocking ? 1.08 : 1
                Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

                // Giriş animasyonu: saat yukarıdan süzülür.
                property real intro: 0
                Component.onCompleted: introAnim.start()
                NumberAnimation { id: introAnim; target: stage; property: "intro"; from: 0; to: 1; duration: 900; easing.type: Easing.OutQuint }

                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.12 - (1 - stage.intro) * 40 }
                    opacity: stage.intro
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Sys.dateLong
                        color: Theme.text
                        opacity: 0.8
                        font { family: Theme.font; pixelSize: 18; letterSpacing: 3; weight: Font.Medium }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Sys.time
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 168; weight: Font.Thin; features: { "tnum": 1 } }
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1; shadowOpacity: 0.35; shadowColor: "#000" }
                    }
                }

                // Alt orta: kullanıcı ve parola
                Column {
                    id: login
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.14 }
                    spacing: 18
                    opacity: stage.intro

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 84; height: 84; radius: 42
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.violet }
                        }
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                        Text {
                            anchors.centerIn: parent
                            text: (Quickshell.env("USER") ?? "?").charAt(0).toUpperCase()
                            color: Theme.onAccent
                            font { family: Theme.font; pixelSize: 34; weight: Font.DemiBold }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Quickshell.env("USER") ?? ""
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 18; weight: Font.Medium }
                    }

                    Glass {
                        id: field
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320; height: 48; radius: 24
                        color: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.55)
                        border.color: input.activeFocus ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.55) : Theme.strokeHi

                        // Yanlış parolada sallanma
                        transform: Translate { id: shakeT }
                        SequentialAnimation {
                            id: shake
                            loops: 1
                            NumberAnimation { target: shakeT; property: "x"; to: -14; duration: 50 }
                            NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 70 }
                            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 70 }
                            NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 60 }
                            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
                        }
                        Connections {
                            target: pam
                            function onFailed() { shake.start(); input.text = ""; hint.text = "Parola yanlış"; }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 20; rightMargin: 6 }
                            Icon { name: "lock"; size: 16; color: Theme.textDim }
                            TextInput {
                                id: input
                                Layout.fillWidth: true
                                focus: true
                                echoMode: TextInput.Password
                                passwordCharacter: "●"
                                color: Theme.text
                                font { family: Theme.font; pixelSize: 15; letterSpacing: 2 }
                                enabled: !pam.active
                                Text {
                                    visible: !input.text
                                    text: "Parola"
                                    color: Theme.textFaint
                                    font { family: Theme.font; pixelSize: 15 }
                                }
                                onAccepted: if (text) { pam.password = text; hint.text = ""; pam.start(); }
                                Component.onCompleted: forceActiveFocus()
                            }
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: input.text ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                                Icon { anchors.centerIn: parent; name: "chevron-right"; size: 18; color: input.text ? Theme.onAccent : Theme.textDim }
                                MouseArea { anchors.fill: parent; onClicked: input.accepted() }
                            }
                        }
                    }
                    Text {
                        id: hint
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ""
                        color: Theme.danger
                        font { family: Theme.font; pixelSize: 12 }
                        height: 14
                    }
                }

                // Sol alt: şu an çalan
                Glass {
                    visible: surface.player !== null
                    anchors { left: parent.left; bottom: parent.bottom; margins: 48 }
                    width: 320; height: 76; radius: 18
                    color: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.5)
                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 52; Layout.preferredHeight: 52; radius: 10; clip: true; color: Theme.glassHi
                            Image { anchors.fill: parent; source: surface.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop }
                        }
                        Column {
                            Layout.fillWidth: true
                            Text { width: parent.width; elide: Text.ElideRight; text: surface.player?.trackTitle ?? ""; color: Theme.text; font { family: Theme.font; pixelSize: 13; weight: Font.Medium } }
                            Text { width: parent.width; elide: Text.ElideRight; text: surface.player?.trackArtist ?? ""; color: Theme.textDim; font { family: Theme.font; pixelSize: 11 } }
                        }
                        IconButton { icon: surface.player?.isPlaying ? "pause" : "play"; onClicked: surface.player?.togglePlaying() }
                    }
                }

                // Sağ alt: pil, ağ, güç
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 48 }
                    spacing: 8
                    IconButton {
                        visible: Sys.hasBattery
                        icon: Sys.charging ? "battery-charging" : "battery-medium"
                        label: "%" + Sys.batteryPercent
                    }
                    IconButton { icon: Sys.netKind === "none" ? "wifi-off" : "wifi" }
                    IconButton { icon: "moon"; onClicked: Sys.suspend() }
                    IconButton { icon: "power"; onClicked: Sys.poweroff() }
                }
            }
        }
    }
}
