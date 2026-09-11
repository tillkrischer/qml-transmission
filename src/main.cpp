#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "CredentialStore.h"
#include "TorrentFileReader.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName(QStringLiteral("qml-transmission"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("qml-transmission.local"));
    QCoreApplication::setApplicationName(QStringLiteral("QML Transmission"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.2.0"));

    QGuiApplication app(argc, argv);
    CredentialStore credentialStore;
    TorrentFileReader torrentFileReader;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("credentialStore"), &credentialStore);
    engine.rootContext()->setContextProperty(QStringLiteral("torrentFileReader"), &torrentFileReader);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("QmlTransmission"), QStringLiteral("Main"));
    return app.exec();
}
