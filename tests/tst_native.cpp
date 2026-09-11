#include <QtTest>
#include <QSignalSpy>
#include <QTemporaryFile>
#include "TorrentFileReader.h"

class NativeServicesTest : public QObject
{
    Q_OBJECT
private slots:
    void readsBinaryExactly()
    {
        QTemporaryFile file;
        QVERIFY(file.open());
        const QByteArray source("\0\1\xfftorrent", 10);
        QCOMPARE(file.write(source), source.size());
        file.flush();
        TorrentFileReader reader;
        QSignalSpy spy(&reader, &TorrentFileReader::finished);
        reader.read("one", QUrl::fromLocalFile(file.fileName()));
        QVERIFY(spy.wait());
        const auto args = spy.takeFirst();
        QCOMPARE(QByteArray::fromBase64(args.at(1).toString().toLatin1()), source);
        QVERIFY(args.at(2).toString().isEmpty());
    }

    void rejectsNonLocal()
    {
        TorrentFileReader reader;
        QSignalSpy spy(&reader, &TorrentFileReader::finished);
        reader.read("two", QUrl("https://example.invalid/a.torrent"));
        QVERIFY(spy.wait());
        QVERIFY(!spy.takeFirst().at(2).toString().isEmpty());
    }
};

QTEST_GUILESS_MAIN(NativeServicesTest)
#include "tst_native.moc"
