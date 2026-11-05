#pragma once
#include <QObject>
#include <QVariant>
#include <QProcess>
#include <QQmlEngine>

// QML'e açılan yerel yardımcılar: dosya sistemi ve süreç çalıştırma.
class Fs : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString home READ home CONSTANT)
public:
    explicit Fs(QObject *parent = nullptr) : QObject(parent) {}
    QString home() const;

    Q_INVOKABLE QVariantList list(const QString &path, bool hidden, const QString &sortKey, bool desc) const;
    Q_INVOKABLE QVariantList recent(int limit) const;
    Q_INVOKABLE QVariantMap info(const QString &path) const;
    Q_INVOKABLE QVariantMap storage(const QString &path) const;
    Q_INVOKABLE QString userDir(const QString &key) const;   // DESKTOP, DOWNLOAD, DOCUMENTS, PICTURES, MUSIC, VIDEOS
    Q_INVOKABLE int countEntries(const QString &path) const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE bool mkdir(const QString &path) const;
    Q_INVOKABLE bool rename(const QString &from, const QString &to) const;
    Q_INVOKABLE void open(const QString &path) const;
    Q_INVOKABLE void trash(const QStringList &paths) const;
    Q_INVOKABLE void copy(const QStringList &paths, const QString &destDir) const;
    Q_INVOKABLE void move(const QStringList &paths, const QString &destDir) const;
    Q_INVOKABLE QString formatSize(qint64 bytes) const;
    Q_INVOKABLE QString formatTime(qint64 msecs) const;
    Q_INVOKABLE QString iconFor(const QString &path) const;   // lucide simge adı
    Q_INVOKABLE QStringList starred() const;
    Q_INVOKABLE void setStarred(const QString &path, bool on) const;

signals:
    void changed(const QString &dir);
};

// Arka planda komut çalıştırır; çıktı tamamlanınca sinyal verir.
class Proc : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QStringList command MEMBER m_command NOTIFY commandChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
public:
    explicit Proc(QObject *parent = nullptr);
    bool running() const { return m_proc.state() != QProcess::NotRunning; }
    Q_INVOKABLE void start();
    Q_INVOKABLE void startWith(const QStringList &command);
    Q_INVOKABLE void kill() { m_proc.kill(); }
    Q_INVOKABLE static void detached(const QStringList &command);
signals:
    void commandChanged();
    void runningChanged();
    void finished(int code, const QString &out, const QString &err);
    void line(const QString &text);
private:
    QProcess m_proc;
    QStringList m_command;
    QByteArray m_buf;
};
