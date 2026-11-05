import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "../services"
import "../components"

// Yönetici izni penceresi (polkit). Güncelleme, sürücü ve uygulama kurulumu gibi
// işlemler parola istediğinde terminal açılmadan burada sorulur.
Scope {
    id: root

    PolkitAgent { id: agent }
    readonly property var flow: agent.flow

    PanelWindow {
        visible: agent.isActive
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(0, 0, 0, 0.45)
        WlrLayershell.namespace: "ayaz-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) { input.text = ""; input.forceActiveFocus(); }

        Glass {
            anchors.centerIn: parent
            width: 420
            height: col.implicitHeight + 48
            radius: Theme.rWindow
            color: Qt.rgba(14 / 255, 19 / 255, 28 / 255, 0.92)
            border.color: Theme.strokeHi

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: 24 }
                spacing: 14

                RowLayout {
                    spacing: 14
                    Rectangle {
                        width: 44; height: 44; radius: 14
                        color: Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.16)
                        Icon { anchors.centerIn: parent; name: "shield-check"; size: 22; color: Theme.accent }
                    }
                    Column {
                        Layout.fillWidth: true
                        Text { text: "İzin gerekiyor"; color: Theme.text; font { family: Theme.font; pixelSize: 16; weight: Font.DemiBold } }
                        Text {
                            width: parent.width
                            text: root.flow?.message ?? ""
                            wrapMode: Text.Wrap
                            color: Theme.textDim
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 44; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: root.flow?.failed ? Theme.danger : (input.activeFocus ? Qt.rgba(169 / 255, 193 / 255, 242 / 255, 0.5) : Theme.stroke)
                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 14 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !input.text
                            text: "Parola"
                            color: Theme.textFaint
                            font: input.font
                        }
                        onAccepted: if (root.flow) root.flow.submit(text)
                        Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()
                    }
                }
                Text {
                    visible: text !== ""
                    text: root.flow?.failed ? "Parola yanlış, tekrar dene." : (root.flow?.supplementaryMessage ?? "")
                    color: root.flow?.failed || root.flow?.supplementaryIsError ? Theme.danger : Theme.textDim
                    font { family: Theme.font; pixelSize: 12 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 96; height: 38; radius: 12
                        color: cancelMouse.containsMouse ? Theme.hover : "transparent"
                        border.width: 1; border.color: Theme.stroke
                        Text { anchors.centerIn: parent; text: "Vazgeç"; color: Theme.text; font { family: Theme.font; pixelSize: 13 } }
                        MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.flow?.cancelAuthenticationRequest() }
                    }
                    Rectangle {
                        width: 110; height: 38; radius: 12
                        color: Theme.accent
                        Text { anchors.centerIn: parent; text: "İzin ver"; color: Theme.accentInk; font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold } }
                        MouseArea { anchors.fill: parent; onClicked: input.accepted() }
                    }
                }
            }
        }
    }
}
