#include "native.h"
#include <QDir>
#include <QFileInfo>
#include <QDateTime>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QMimeDatabase>
#include <QDesktopServices>
#include <QUrl>
#include <QFile>
#include <QXmlStreamReader>
#include <QSettings>
#include <QLocale>
#include <algorithm>

QString Fs::home() const { return QDir::homePath(); }

static QVariantMap entry(const QFileInfo &fi, const Fs *fs)
{
    QVariantMap m;
    m["name"] = fi.fileName();
    m["path"] = fi.absoluteFilePath();
    m["dir"] = fi.isDir();
    m["size"] = fi.isDir() ? -1 : fi.size();
    m["mtime"] = fi.lastModified().toMSecsSinceEpoch();
    m["icon"] = fs->iconFor(fi.absoluteFilePath());
    m["parent"] = fi.dir().dirName();
    m["hidden"] = fi.isHidden();
    return m;
}

QVariantList Fs::list(const QString &path, bool hidden, const QString &sortKey, bool desc) const
{
    QDir d(path);
    auto filters = QDir::AllEntries | QDir::NoDotAndDotDot;
    if (hidden) filters |= QDir::Hidden;
    QDir::SortFlags sort = QDir::DirsFirst | QDir::IgnoreCase | QDir::LocaleAware;
    if (sortKey == "mtime") sort |= QDir::Time;
    else if (sortKey == "size") sort |= QDir::Size;
    else sort |= QDir::Name;
    if (desc != (sortKey == "mtime" || sortKey == "size")) sort |= QDir::Reversed;
    QVariantList out;
    for (const QFileInfo &fi : d.entryInfoList(filters, sort))
        out << entry(fi, this);
    return out;
}

// GTK/GNOME uyumlu son kullanılanlar listesi (~/.local/share/recently-used.xbel)
QVariantList Fs::recent(int limit) const
{
    QFile f(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/recently-used.xbel");
    QList<QPair<qint64, QString>> items;
    if (f.open(QIODevice::ReadOnly)) {
        QXmlStreamReader x(&f);
        while (!x.atEnd()) {
            if (x.readNext() == QXmlStreamReader::StartElement && x.name() == u"bookmark") {
                QUrl u(x.attributes().value("href").toString());
                if (!u.isLocalFile()) continue;
                auto when = QDateTime::fromString(x.attributes().value("modified").toString(), Qt::ISODate);
                items.append({when.toMSecsSinceEpoch(), u.toLocalFile()});
            }
        }
    }
    std::sort(items.begin(), items.end(), [](auto &a, auto &b) { return a.first > b.first; });
    QVariantList out;
    for (auto &it : items) {
        QFileInfo fi(it.second);
        if (!fi.exists()) continue;
        out << entry(fi, this);
        if (out.size() >= limit) break;
    }
    // Liste boşsa ev dizinindeki en son değişen dosyalar
    if (out.isEmpty()) {
        QList<QFileInfo> all;
        const auto top = QDir::home().entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QFileInfo &dir : top)
            all += QDir(dir.absoluteFilePath()).entryInfoList(QDir::Files | QDir::NoDotAndDotDot, QDir::Time).mid(0, 20);
        all += QDir::home().entryInfoList(QDir::Files | QDir::NoDotAndDotDot, QDir::Time).mid(0, 20);
        std::sort(all.begin(), all.end(), [](auto &a, auto &b) { return a.lastModified() > b.lastModified(); });
        for (auto &fi : all) { out << entry(fi, this); if (out.size() >= limit) break; }
    }
    return out;
}

QVariantMap Fs::info(const QString &path) const { return entry(QFileInfo(path), this); }

QVariantMap Fs::storage(const QString &path) const
{
    QStorageInfo s(path);
    return {{"total", s.bytesTotal()}, {"free", s.bytesAvailable()}, {"name", s.displayName()}};
}

QString Fs::userDir(const QString &key) const
{
    static const QHash<QString, QStandardPaths::StandardLocation> map = {
        {"DESKTOP", QStandardPaths::DesktopLocation}, {"DOWNLOAD", QStandardPaths::DownloadLocation},
        {"DOCUMENTS", QStandardPaths::DocumentsLocation}, {"PICTURES", QStandardPaths::PicturesLocation},
        {"MUSIC", QStandardPaths::MusicLocation}, {"VIDEOS", QStandardPaths::MoviesLocation}};
    return QStandardPaths::writableLocation(map.value(key, QStandardPaths::HomeLocation));
}

int Fs::countEntries(const QString &path) const { return QDir(path).entryList(QDir::AllEntries | QDir::NoDotAndDotDot).size(); }
bool Fs::exists(const QString &path) const { return QFileInfo::exists(path); }
bool Fs::mkdir(const QString &path) const { bool ok = QDir().mkpath(path); emit const_cast<Fs*>(this)->changed(QFileInfo(path).absolutePath()); return ok; }
bool Fs::rename(const QString &from, const QString &to) const { bool ok = QFile::rename(from, to); emit const_cast<Fs*>(this)->changed(QFileInfo(from).absolutePath()); return ok; }
void Fs::open(const QString &path) const { QDesktopServices::openUrl(QUrl::fromLocalFile(path)); }

static void gio(const QStringList &args, const QString &dir, const Fs *fs)
{
    auto *p = new QProcess(const_cast<Fs*>(fs));
    QObject::connect(p, &QProcess::finished, p, [p, dir, fs] { emit const_cast<Fs*>(fs)->changed(dir); p->deleteLater(); });
    p->start("gio", args);
}
void Fs::trash(const QStringList &paths) const { if (!paths.isEmpty()) gio(QStringList{"trash"} + paths, QFileInfo(paths.first()).absolutePath(), this); }
void Fs::copy(const QStringList &paths, const QString &d) const { if (!paths.isEmpty()) gio(QStringList{"copy", "-b"} + paths + QStringList{d}, d, this); }
void Fs::move(const QStringList &paths, const QString &d) const { if (!paths.isEmpty()) gio(QStringList{"move", "-b"} + paths + QStringList{d}, d, this); }

QString Fs::formatSize(qint64 b) const
{
    if (b < 0) return QString();
    QLocale tr(QLocale::Turkish);
    if (b < 1024) return QString("%1 B").arg(b);
    if (b < 1024 * 1024) return tr.toString(b / 1024.0, 'f', 0) + " KB";
    if (b < 1024LL * 1024 * 1024) return tr.toString(b / 1048576.0, 'f', 1) + " MB";
    return tr.toString(b / 1073741824.0, 'f', 1) + " GB";
}

QString Fs::formatTime(qint64 ms) const
{
    QDateTime t = QDateTime::fromMSecsSinceEpoch(ms);
    QDate today = QDate::currentDate();
    QLocale tr(QLocale::Turkish);
    if (t.date() == today) return "Bugün, " + t.toString("HH:mm");
    if (t.date() == today.addDays(-1)) return "Dün, " + t.toString("HH:mm");
    if (t.date().year() == today.year()) return tr.toString(t, "d MMM, HH:mm");
    return tr.toString(t.date(), "d MMM yyyy");
}

QString Fs::iconFor(const QString &path) const
{
    QFileInfo fi(path);
    if (fi.isDir()) return "folder";
    static QMimeDatabase db;
    const QString m = db.mimeTypeForFile(fi).name();
    if (m.startsWith("image/")) return "image";
    if (m.startsWith("audio/")) return "audio-lines";
    if (m.startsWith("video/")) return "film";
    if (m.contains("zip") || m.contains("tar") || m.contains("compressed") || m.contains("7z") || m.contains("rar")) return "archive";
    if (m == "application/x-ms-dos-executable" || m == "application/x-msdownload" || m == "application/vnd.microsoft.portable-executable") return "app-window";
    if (m.contains("pdf")) return "file-text";
    if (fi.suffix() == "fig" || m.contains("figma")) return "figma";
    if (m.startsWith("text/") || m.contains("json") || m.contains("xml") || m.contains("document")) return "file-text";
    return "file";
}

static QString starFile() { return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/starred.ini"; }
QStringList Fs::starred() const { return QSettings(starFile(), QSettings::IniFormat).value("paths").toStringList(); }
void Fs::setStarred(const QString &path, bool on) const
{
    QSettings s(starFile(), QSettings::IniFormat);
    QStringList l = s.value("paths").toStringList();
    l.removeAll(path);
    if (on) l.prepend(path);
    s.setValue("paths", l);
}

Proc::Proc(QObject *parent) : QObject(parent)
{
    connect(&m_proc, &QProcess::stateChanged, this, &Proc::runningChanged);
    connect(&m_proc, &QProcess::readyReadStandardOutput, this, [this] {
        QByteArray chunk = m_proc.readAllStandardOutput();
        m_buf += chunk;
        for (const QByteArray &l : chunk.split('\n')) if (!l.isEmpty()) emit line(QString::fromUtf8(l));
    });
    connect(&m_proc, &QProcess::finished, this, [this](int code) {
        emit finished(code, QString::fromUtf8(m_buf), QString::fromUtf8(m_proc.readAllStandardError()));
        m_buf.clear();
    });
}
void Proc::start() { if (m_command.isEmpty() || running()) return; m_buf.clear(); m_proc.start(m_command.first(), m_command.mid(1)); }
void Proc::startWith(const QStringList &c) { m_command = c; emit commandChanged(); start(); }
void Proc::detached(const QStringList &c) { if (!c.isEmpty()) QProcess::startDetached(c.first(), c.mid(1)); }
