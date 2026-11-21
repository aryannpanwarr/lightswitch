#include "notes.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrl>

namespace {
const QRegularExpression &itemPattern() {
    static const QRegularExpression pattern(R"(^- \[( |x|X)\] (\d{4}-\d\d-\d\d \d\d:\d\d) · (.*)$)");
    return pattern;
}
const char *timeFormat = "yyyy-MM-dd HH:mm";
}

Notes::Notes(const QString &path, const QString &draftPath, QObject *parent)
    : QObject(parent),
      m_path(path.isEmpty() ? QDir::homePath() + "/Notes/lightswitch.md" : path),
      m_draftPath(draftPath.isEmpty() ? QDir::homePath() + "/.local/state/lightswitch/draft.txt" : draftPath) {
    // Edits made in another editor show up here too. Editors replace the file
    // on save, which drops it from the watch, so watch the folder and re-arm.
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &Notes::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Notes::reload);

    QFile draft(m_draftPath);
    if (draft.open(QIODevice::ReadOnly))
        m_draft = QString::fromUtf8(draft.readAll());
    reload();
}

QString Notes::formatItem(const QDateTime &when, const QString &text) {
    return QStringLiteral("- [ ] %1 · %2").arg(when.toString(timeFormat), text);
}

void Notes::setDraft(const QString &draft) {
    if (draft == m_draft)
        return;
    m_draft = draft;
    emit draftChanged();
}

void Notes::saveDraft() {
    // The draft survives a crash or a reboot, so a half-typed thought is never
    // lost just because the window was dismissed.
    if (m_draft.isEmpty()) {
        QFile::remove(m_draftPath);
        return;
    }
    QDir().mkpath(QFileInfo(m_draftPath).absolutePath());
    QSaveFile file(m_draftPath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(m_draft.toUtf8());
        file.commit();
    }
}

QStringList Notes::readLines() const {
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QStringList lines = QString::fromUtf8(file.readAll()).split('\n');
    if (!lines.isEmpty() && lines.last().isEmpty())
        lines.removeLast();
    return lines;
}

bool Notes::writeLines(const QStringList &lines) {
    QDir().mkpath(QFileInfo(m_path).absolutePath());
    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly) || file.write((lines.join('\n') + '\n').toUtf8()) < 0 || !file.commit()) {
        setError(tr("Couldn't save %1").arg(m_path));
        return false;
    }
    setError({});
    return true;
}

int Notes::capture(const QString &text, const QDateTime &when) {
    QStringList items;
    for (const QString &line : text.split('\n')) {
        const QString trimmed = line.trimmed();
        if (!trimmed.isEmpty())
            items << formatItem(when, trimmed);
    }
    if (items.isEmpty())
        return 0;

    QStringList lines = readLines();
    if (lines.isEmpty())
        lines << "# Lightswitch" << "";
    lines << items;
    if (!writeLines(lines))
        return -1;
    reload();
    return items.size();
}

bool Notes::replaceLine(int line, const QString &from, const QString &to) {
    QStringList lines = readLines();
    // The file may have changed under us; only touch the line if it is still
    // the item the user saw.
    if (line < 0 || line >= lines.size() || !lines[line].startsWith(from))
        return false;
    lines[line] = to + lines[line].mid(from.size());
    if (!writeLines(lines))
        return false;
    return true;
}

bool Notes::markDone(int line) {
    if (!replaceLine(line, "- [ ] ", "- [x] "))
        return false;
    m_undo << line;
    reload();
    return true;
}

bool Notes::undo() {
    if (m_undo.isEmpty())
        return false;
    const int line = m_undo.takeLast();
    const bool ok = replaceLine(line, "- [x] ", "- [ ] ");
    reload();
    return ok;
}

void Notes::openFile() const {
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_path));
}

void Notes::setError(const QString &error) {
    if (error == m_error)
        return;
    m_error = error;
    emit errorChanged();
}

void Notes::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    const QString dir = QFileInfo(m_path).absolutePath();
    if (QFileInfo::exists(dir))
        m_watcher.addPath(dir);
    if (QFileInfo::exists(m_path))
        m_watcher.addPath(m_path);
}

void Notes::reload() {
    watch();
    const QStringList lines = readLines();
    const QDate today = QDate::currentDate();
    QVariantList open;
    // Newest first: what was just dumped is what the user is most likely to
    // want to see again.
    for (int i = lines.size() - 1; i >= 0; --i) {
        const auto match = itemPattern().match(lines[i]);
        if (!match.hasMatch() || match.captured(1) != " ")
            continue;
        const QDateTime when = QDateTime::fromString(match.captured(2), timeFormat);
        const QString label = when.date() == today ? QLocale().toString(when.time(), QLocale::ShortFormat)
                            : when.date().year() == today.year() ? QLocale().toString(when.date(), "d MMM")
                            : QLocale().toString(when.date(), "d MMM yyyy");
        open << QVariantMap{{"line", i}, {"text", match.captured(3)}, {"when", label}};
    }
    m_open = open;
    emit changed();
}
