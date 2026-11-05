// ayaz-app: AyazOS sistem uygulamalarını çalıştıran ortak taşıyıcı.
//   ayaz-app <uygulama> [argümanlar]
// QML: /usr/share/ayazos/apps/<uygulama>/Main.qml
// Ortak bileşenler: import AyazOS.UI, yerel yardımcılar: import AyazOS.Native
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QDir>
#include "native.h"

int main(int argc, char *argv[])
{
    if (argc < 2) { qWarning("kullanım: ayaz-app <uygulama>"); return 2; }
    const QString app = QString::fromLocal8Bit(argv[1]);
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QGuiApplication a(argc, argv);
    a.setOrganizationName("AyazOS");
    a.setApplicationName(app);
    a.setDesktopFileName("ayaz-" + app);   // Wayland app_id: dock eşleşmesi için
    a.setWindowIcon(QIcon::fromTheme("ayazos"));

    QString base = qEnvironmentVariable("AYAZ_APPS_DIR", "/usr/share/ayazos/apps");
    QQmlApplicationEngine engine;
    engine.addImportPath(qEnvironmentVariable("AYAZ_QML_DIR", "/usr/share/ayazos/qml"));
    auto *fs = new Fs(&a);
    qmlRegisterSingletonInstance("AyazOS.Native", 1, 0, "Fs", fs);
    qmlRegisterType<Proc>("AyazOS.Native", 1, 0, "Proc");
    engine.rootContext()->setContextProperty("appArgs", a.arguments().mid(2));
    engine.load(QUrl::fromLocalFile(base + "/" + app + "/Main.qml"));
    if (engine.rootObjects().isEmpty()) return 1;
    return a.exec();
}
