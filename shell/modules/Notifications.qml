import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../services"
import "../components"

// Bildirimler: sağ üstte cam kartlar olarak sağdan kayarak gelir.
// Odak kipinde yalnızca kritik bildirimler gösterilir.
Scope {
    id: root

    ListModel { id: popups }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true;
            if (Shell.focusMode && n.urgency !== NotificationUrgency.Critical) return;
            popups.insert(0, { notif: n });
        }
    }

    function remove(n) {
        for (let i = 0; i < popups.count; i++)
            if (popups.get(i).notif === n) { popups.remove(i); return; }
    }

    PanelWindow {
        visible: popups.count > 0
        anchors { top: true; right: true }
        margins { top: 54; right: 16 }
        implicitWidth: 380
        implicitHeight: Math.max(1, list.contentHeight)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "ayaz-notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        ListView {
            id: list
            anchors.fill: parent
            model: popups
            spacing: 10
            interactive: false
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: 400; to: 0; duration: 380; easing.type: Easing.OutQuint }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; to: 400; duration: 260; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: 220 }
                }
            }
            displaced: Transition { NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic } }

            delegate: Glass {
                id: card
                required property var notif
                width: list.width
                height: body.implicitHeight + 28
                radius: 18
                color: Qt.rgba(14 / 255, 19 / 255, 28 / 255, 0.9)

                Timer {
                    running: card.notif && card.notif.urgency !== NotificationUrgency.Critical && !hover.containsMouse
                    interval: card.notif && card.notif.expireTimeout > 0 ? card.notif.expireTimeout * 1000 : 6000
                    onTriggered: { card.notif.expire(); root.remove(card.notif); }
                }
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: { card.notif.dismiss(); root.remove(card.notif); } }

                RowLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 12
                    IconImage {
                        Layout.alignment: Qt.AlignTop
                        implicitSize: 36
                        source: card.notif?.image || Quickshell.iconPath(card.notif?.appIcon || "dialog-information", "dialog-information")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        RowLayout {
                            Text {
                                Layout.fillWidth: true
                                text: card.notif?.appName ?? ""
                                color: Theme.textDim
                                elide: Text.ElideRight
                                font { family: Theme.font; pixelSize: 11 }
                            }
                            Text { text: Sys.time; color: Theme.textFaint; font { family: Theme.font; pixelSize: 11 } }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: card.notif?.summary ?? ""
                            color: Theme.text
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.notif?.body ?? ""
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font { family: Theme.font; pixelSize: 12 }
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 6
                            visible: (card.notif?.actions.length ?? 0) > 0
                            Repeater {
                                model: card.notif?.actions ?? []
                                Rectangle {
                                    required property var modelData
                                    height: 30; width: label.implicitWidth + 24; radius: 10
                                    color: Qt.rgba(1, 1, 1, 0.07)
                                    Text { id: label; anchors.centerIn: parent; text: modelData.text; color: Theme.text; font { family: Theme.font; pixelSize: 12 } }
                                    MouseArea { anchors.fill: parent; onClicked: { modelData.invoke(); root.remove(card.notif); } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
