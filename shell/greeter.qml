import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import "services"
import "components"

// AyazOS giriş ekranı (greetd). Kilit ekranıyla aynı görsel dil.
ShellRoot {
    id: root
    property string user: ""
    property var users: []
    property string error: ""
    property bool busy: false
    property bool leaving: false

    // Gerçek kullanıcılar: UID 1000-59999 ve giriş kabuğu olanlar.
    Process {
        running: true
        command: ["sh", "-c", "getent passwd | awk -F: '$3>=1000 && $3<60000 && $7 !~ /nologin|false/ {print $1\":\"$5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.users = text.trim().split("\n").filter(l => l).map(l => {
                    const [name, gecos] = l.split(":");
                    return { name: name, full: (gecos || "").split(",")[0] || name };
                });
                if (root.users.length > 0 && !root.user) root.user = root.users[0].name;
            }
        }
    }

    function login(password) {
        if (!user || busy) return;
        busy = true;
        error = "";
        pending = password;
        Greetd.createSession(user);
    }
    property string pending: ""

    Connections {
        target: Greetd
        function onAuthMessage(message, isError, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.pending);
            else if (isError) root.error = message;
        }
        function onAuthFailure(message) {
            root.busy = false;
            root.error = "Parola yanlış";
            root.pending = "";
            Greetd.cancelSession();
            root.failed();
        }
        function onReadyToLaunch() {
            root.leaving = true;
            launchTimer.start();
        }
        function onError(message) {
            root.busy = false;
            root.error = message;
        }
    }
    signal failed()
    Timer { id: launchTimer; interval: 450; onTriggered: Greetd.launch(["ayazos-session"]) }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "#05070C"

            Image {
                id: wall
                anchors.fill: parent
                source: "file:///usr/share/backgrounds/ayazos/default.jpg"
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blurMax: 64
                blur: root.leaving ? 0 : 1
                brightness: root.leaving ? 0 : -0.2
                Behavior on blur { NumberAnimation { duration: 450 } }
                Behavior on brightness { NumberAnimation { duration: 450 } }
            }

            Item {
                anchors.fill: parent
                opacity: root.leaving ? 0 : 1
                scale: root.leaving ? 1.06 : 1
                Behavior on opacity { NumberAnimation { duration: 400 } }
                Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.12 }
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Sys.dateLong
                        color: Theme.text; opacity: 0.8
                        font { family: Theme.font; pixelSize: 18; letterSpacing: 3; weight: Font.Medium }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Sys.time
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 168; weight: Font.Thin; features: { "tnum": 1 } }
                    }
                }

                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.14 }
                    spacing: 18

                    // Birden fazla kullanıcı varsa seçici.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 22
                        Repeater {
                            model: root.users
                            Item {
                                id: ucell
                                required property var modelData
                                readonly property bool sel: root.user === modelData.name
                                width: ucol.implicitWidth
                                height: ucol.implicitHeight
                                opacity: sel ? 1 : 0.55
                                scale: sel ? 1 : 0.8
                                Behavior on scale { NumberAnimation { duration: Theme.dNormal; easing.type: Easing.OutCubic } }
                                Column {
                                    id: ucol
                                    spacing: 10
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 84; height: 84; radius: 42
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: Theme.accent }
                                            GradientStop { position: 1; color: Theme.violet }
                                        }
                                        border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.35)
                                        Text {
                                            anchors.centerIn: parent
                                            text: ucell.modelData.full.charAt(0).toUpperCase()
                                            color: Theme.accentInk
                                            font { family: Theme.font; pixelSize: 34; weight: Font.DemiBold }
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: ucell.modelData.full
                                        color: Theme.text
                                        font { family: Theme.font; pixelSize: 18; weight: Font.Medium }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { root.user = ucell.modelData.name; input.forceActiveFocus(); }
                                }
                            }
                        }
                    }

                    Glass {
                        id: field
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320; height: 48; radius: 24
                        color: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.55)
                        border.color: input.activeFocus ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.55) : Theme.strokeHi
                        transform: Translate { id: shakeT }
                        SequentialAnimation {
                            id: shake
                            NumberAnimation { target: shakeT; property: "x"; to: -14; duration: 50 }
                            NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 70 }
                            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 70 }
                            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
                        }
                        Connections { target: root; function onFailed() { shake.start(); input.text = ""; } }

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
                                enabled: !root.busy
                                font { family: Theme.font; pixelSize: 15; letterSpacing: 2 }
                                Text {
                                    visible: !input.text
                                    text: "Parola"
                                    color: Theme.textFaint
                                    font { family: Theme.font; pixelSize: 15 }
                                }
                                onAccepted: root.login(text)
                                Component.onCompleted: forceActiveFocus()
                            }
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: input.text ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                                Icon { anchors.centerIn: parent; name: "chevron-right"; size: 18; color: input.text ? Theme.accentInk : Theme.textDim }
                                MouseArea { anchors.fill: parent; onClicked: root.login(input.text) }
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.error
                        color: Theme.danger
                        height: 14
                        font { family: Theme.font; pixelSize: 12 }
                    }
                }

                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 48 }
                    spacing: 8
                    IconButton { icon: "rotate-ccw"; onClicked: Sys.reboot() }
                    IconButton { icon: "power"; onClicked: Sys.poweroff() }
                }
                Image {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 48 }
                    width: 28; height: 28
                    sourceSize: Qt.size(56, 56)
                    source: Qt.resolvedUrl("assets/ayazos-mark.svg")
                    opacity: 0.8
                }
            }
        }
    }
}
