#include "TorrentFileReader.h"

#include <QFile>
#include <QMetaObject>
#include <QPointer>
#include <QRunnable>
#include <QThreadPool>
#include <QUrl>

TorrentFileReader::TorrentFileReader(QObject *parent) : QObject(parent) {}

void TorrentFileReader::cancel(const QString &token)
{
    m_cancelled.insert(token);
}

void TorrentFileReader::read(const QString &token, const QUrl &url)
{
    m_cancelled.remove(token);
    const QString path = url.isLocalFile() ? url.toLocalFile() : QString();
    QPointer<TorrentFileReader> guard(this);
    QThreadPool::globalInstance()->start(QRunnable::create([guard, token, path] {
        QByteArray bytes;
        QString error;
        if (path.isEmpty()) {
            error = QStringLiteral("Choose a local .torrent file");
        } else {
            QFile file(path);
            if (!file.open(QIODevice::ReadOnly))
                error = QStringLiteral("Cannot read the torrent file: %1").arg(file.errorString());
            else {
                bytes = file.read(TorrentFileReader::MaximumBytes + 1);
                if (bytes.isEmpty())
                    error = QStringLiteral("The torrent file is empty");
                else if (bytes.size() > TorrentFileReader::MaximumBytes) {
                    bytes.clear();
                    error = QStringLiteral("The torrent file exceeds the 32 MiB limit");
                }
            }
        }
        if (!guard)
            return;
        const QString encoded = QString::fromLatin1(bytes.toBase64());
        QMetaObject::invokeMethod(guard, [guard, token, encoded, error] {
            if (!guard || guard->m_cancelled.remove(token))
                return;
            emit guard->finished(token, encoded, error);
        }, Qt::QueuedConnection);
    }));
}
