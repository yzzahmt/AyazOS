pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Kabuk geneli durum: başlat menüsü, kontrol merkezi, odak kipi.
Singleton {
    id: root

    property bool startOpen: false
    property bool controlOpen: false
    property bool focusMode: false
    property int workspace: 1
    property int workspaceCount: 3

    // Dock'a sabitlenen uygulamalar (masaüstü dosyası kimliği, simge).
    readonly property var pinned: [
        { id: "ayaz-files", icon: "folder", name: "Dosyalar" },
        { id: "firefox", icon: "compass", name: "Firefox" },
        { id: "veloneon-notes", icon: "notebook-pen", name: "Veloneon Notes" },
        { id: "ayaz-music", icon: "music", name: "Müzik" },
        { id: "ayaz-gallery", icon: "image", name: "Galeri" },
        { id: "ayaz-terminal", icon: "terminal", name: "Terminal" },
        { id: "ayaz-settings", icon: "sliders-horizontal", name: "Ayarlar" }
    ]

    function launch(id) {
        const e = DesktopEntries.byId(id);
        if (e) e.execute();
        else Quickshell.execDetached(["gtk-launch", id]);
        startOpen = false;
    }

    function toggleStart() {
        controlOpen = false;
        startOpen = !startOpen;
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleStart(); }
        function open(): void { root.startOpen = true; }
        function close(): void { root.startOpen = false; }
    }

    IpcHandler {
        target: "control"
        function toggle(): void { root.startOpen = false; root.controlOpen = !root.controlOpen; }
    }
}
