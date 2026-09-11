#pragma once

#include <QObject>

class CredentialStore final : public QObject
{
    Q_OBJECT
public:
    explicit CredentialStore(QObject *parent = nullptr);

    Q_INVOKABLE QString generateUuid() const;
    Q_INVOKABLE void read(const QString &requestId, const QString &profileId);
    Q_INVOKABLE void write(const QString &requestId, const QString &profileId,
                           const QString &password);
    Q_INVOKABLE void remove(const QString &requestId, const QString &profileId);

signals:
    void readFinished(const QString &requestId, const QString &profileId,
                      const QString &password, const QString &error);
    void writeFinished(const QString &requestId, const QString &profileId,
                       const QString &error);
    void removeFinished(const QString &requestId, const QString &profileId,
                        const QString &error);

private:
    static QString keyFor(const QString &profileId);
};
