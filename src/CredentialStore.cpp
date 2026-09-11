#include "CredentialStore.h"

#include <qt6keychain/keychain.h>
#include <QUuid>

using namespace QKeychain;

static const QString serviceName = QStringLiteral("qml-transmission");

CredentialStore::CredentialStore(QObject *parent) : QObject(parent) {}

QString CredentialStore::generateUuid() const
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QString CredentialStore::keyFor(const QString &profileId)
{
    return QStringLiteral("profile/") + profileId;
}

void CredentialStore::read(const QString &requestId, const QString &profileId)
{
    auto *job = new ReadPasswordJob(serviceName, this);
    job->setAutoDelete(true);
    job->setKey(keyFor(profileId));
    connect(job, &Job::finished, this, [this, job, requestId, profileId] {
        emit readFinished(requestId, profileId,
                          job->error() == NoError ? job->textData() : QString(),
                          job->error() == NoError ? QString() : job->errorString());
    });
    job->start();
}

void CredentialStore::write(const QString &requestId, const QString &profileId,
                            const QString &password)
{
    auto *job = new WritePasswordJob(serviceName, this);
    job->setAutoDelete(true);
    job->setKey(keyFor(profileId));
    job->setTextData(password);
    connect(job, &Job::finished, this, [this, job, requestId, profileId] {
        emit writeFinished(requestId, profileId,
                           job->error() == NoError ? QString() : job->errorString());
    });
    job->start();
}

void CredentialStore::remove(const QString &requestId, const QString &profileId)
{
    auto *job = new DeletePasswordJob(serviceName, this);
    job->setAutoDelete(true);
    job->setKey(keyFor(profileId));
    connect(job, &Job::finished, this, [this, job, requestId, profileId] {
        emit removeFinished(requestId, profileId,
                            job->error() == NoError ? QString() : job->errorString());
    });
    job->start();
}
