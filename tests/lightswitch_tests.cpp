#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

#include "notes.h"
#include "theme.h"

class LightswitchTests : public QObject {
    Q_OBJECT

private slots:
    void captureWritesOneItemPerLine()
    {
        QTemporaryDir dir;
        Notes notes(dir.filePath("n.md"), dir.filePath("d.txt"));
        const QDateTime when(QDate(2026, 11, 22), QTime(14, 3));
        QCOMPARE(notes.capture("call the bank\n\n  buy milk  \n", when), 2);
        QCOMPARE(read(dir.filePath("n.md")),
                 QString("# Lightswitch\n\n- [ ] 2026-11-22 14:03 · call the bank\n- [ ] 2026-11-22 14:03 · buy milk\n"));
        QCOMPARE(notes.openCount(), 2);
        // Newest first.
        QCOMPARE(notes.open().first().toMap()["text"].toString(), QString("buy milk"));
    }

    void emptyCaptureSavesNothing()
    {
        QTemporaryDir dir;
        Notes notes(dir.filePath("n.md"), dir.filePath("d.txt"));
        QCOMPARE(notes.capture("  \n \n"), 0);
        QVERIFY(!QFile::exists(dir.filePath("n.md")));
    }

    void markDoneAndUndo()
    {
        QTemporaryDir dir;
        Notes notes(dir.filePath("n.md"), dir.filePath("d.txt"));
        notes.capture("one\ntwo");
        const int line = notes.open().first().toMap()["line"].toInt();
        QVERIFY(notes.markDone(line));
        QCOMPARE(notes.openCount(), 1);
        QVERIFY(read(dir.filePath("n.md")).contains("- [x] "));
        QVERIFY(notes.undo());
        QCOMPARE(notes.openCount(), 2);
    }

    void keepsLinesItDidNotWrite()
    {
        QTemporaryDir dir;
        write(dir.filePath("n.md"), "my own heading\n- [ ] 2026-01-01 09:00 · old\nfree text\n");
        Notes notes(dir.filePath("n.md"), dir.filePath("d.txt"));
        QCOMPARE(notes.openCount(), 1);
        notes.capture("new", QDateTime(QDate(2026, 2, 1), QTime(8, 0)));
        QCOMPARE(read(dir.filePath("n.md")),
                 QString("my own heading\n- [ ] 2026-01-01 09:00 · old\nfree text\n- [ ] 2026-02-01 08:00 · new\n"));
        // Marking done refuses a line that is no longer an open item.
        QVERIFY(!notes.markDone(0));
    }

    void draftSurvivesRestart()
    {
        QTemporaryDir dir;
        {
            Notes notes(dir.filePath("n.md"), dir.filePath("s/d.txt"));
            notes.setDraft("half a thou");
            notes.saveDraft();
        }
        Notes again(dir.filePath("n.md"), dir.filePath("s/d.txt"));
        QCOMPARE(again.draft(), QString("half a thou"));
        again.setDraft("");
        again.saveDraft();
        QVERIFY(!QFile::exists(dir.filePath("s/d.txt")));
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
    }

private:
    static QString read(const QString &path)
    {
        QFile f(path);
        f.open(QIODevice::ReadOnly);
        return QString::fromUtf8(f.readAll());
    }
    static void write(const QString &path, const QByteArray &data)
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(data);
    }
};

QTEST_MAIN(LightswitchTests)
#include "lightswitch_tests.moc"
