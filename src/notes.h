#pragma once

#include <QDateTime>
#include <QFileSystemWatcher>
#include <QObject>
#include <QStringList>
#include <QVariantList>

// The notes file is plain Markdown the user can open anywhere. Every captured
// line becomes one checklist item:
//
//   - [ ] 2026-11-22 14:03 · call the bank
//
// Lines the app did not write are kept exactly as they are.
class Notes : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList open READ open NOTIFY changed)
    Q_PROPERTY(int openCount READ openCount NOTIFY changed)
    Q_PROPERTY(QString path READ path CONSTANT)
    Q_PROPERTY(QString draft READ draft WRITE setDraft NOTIFY draftChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit Notes(const QString &path = {}, const QString &draftPath = {}, QObject *parent = nullptr);

    QVariantList open() const { return m_open; }
    int openCount() const { return m_open.size(); }
    QString path() const { return m_path; }
    QString draft() const { return m_draft; }
    void setDraft(const QString &draft);
    bool canUndo() const { return !m_undo.isEmpty(); }
    QString error() const { return m_error; }

    // Appends every non-empty line of text as its own item. Returns how many
    // were saved, or -1 when the file could not be written.
    Q_INVOKABLE int capture(const QString &text, const QDateTime &when = QDateTime::currentDateTime());
    Q_INVOKABLE bool markDone(int line);
    Q_INVOKABLE bool undo();
    Q_INVOKABLE void saveDraft();
    Q_INVOKABLE void openFile() const;
    Q_INVOKABLE void reload();

    static QString formatItem(const QDateTime &when, const QString &text);

signals:
    void changed();
    void draftChanged();
    void errorChanged();

private:
    QStringList readLines() const;
    bool writeLines(const QStringList &lines);
    bool replaceLine(int line, const QString &from, const QString &to);
    void setError(const QString &error);
    void watch();

    QString m_path;
    QString m_draftPath;
    QString m_draft;
    QString m_error;
    QVariantList m_open;
    QList<int> m_undo;
    QFileSystemWatcher m_watcher;
};
