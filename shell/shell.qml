//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import QtQuick
import Quickshell
import "modules"
import "services"

// AyazOS masaüstü kabuğu. Wayfire üzerinde Quickshell ile çalışır:
//   qs -c ayazos
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property ShellScreen modelData
            Desktop { screen: perScreen.modelData }
            TopBar { screen: perScreen.modelData }
            Dock { id: dock; screen: perScreen.modelData }
            StartMenu { screen: perScreen.modelData; dockOrigin: dock.startOrigin }
            ControlCenter { screen: perScreen.modelData }
        }
    }
    LockScreen {}
}
