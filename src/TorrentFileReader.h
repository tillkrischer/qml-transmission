#pragma once

#include <QObject>
#include <QSet>

class TorrentFileReader final : public QObject
{
    Q_OBJECT
public:
    static constexpr qint64 MaximumBytes = 32ll * 1024ll * 1024ll;
    explicit TorrentFileReader(QObject *parent = nullptr);

    Q_INVOKABLE void read(const QString &token, const QUrl &url);
    Q_INVOKABLE void cancel(const QString &token);

signals:
    void finished(const QString &token, const QString &base64, const QString &error);

private:
    QSet<QString> m_cancelled;
};
