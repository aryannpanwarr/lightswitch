#include "notes.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrl>

#include <functional>

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
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &Notes::externalChange);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Notes::externalChange);

    QFile draft(m_draftPath);
    if (draft.open(QIODevice::ReadOnly))
        m_draft = QString::fromUtf8(draft.readAll());
    reload();
}

QString Notes::formatItem(const QDateTime &when, const QString &text, bool done) {
    return QStringLiteral("- [%1] %2 · %3").arg(done ? "x" : " ", when.toString(timeFormat), text);
}

QVariantList Notes::open() const {
    QVariantList result;
    for (const QVariant &item : m_items)
        if (!item.toMap().value("done").toBool())
            result << item;
    return result;
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

bool Notes::changeItem(int line, const std::function<QString(bool, const QString &, const QString &)> &change) {
    QStringList lines = readLines();
    // The file may have changed under us (another editor); only touch the line
    // if it is still an item.
    if (line < 0 || line >= lines.size())
        return false;
    const auto match = itemPattern().match(lines[line]);
    if (!match.hasMatch())
        return false;
    const QStringList before = lines;
    const QString replacement = change(match.captured(1) != " ", match.captured(2), match.captured(3));
    if (replacement.isNull())
        lines.removeAt(line);
    else
        lines[line] = replacement;
    if (!writeLines(lines))
        return false;
    m_undo << before;
    if (m_undo.size() > 100)
        m_undo.removeFirst();
    reload();
    return true;
}

bool Notes::setDone(int line, bool done) {
    return changeItem(line, [done](bool, const QString &stamp, const QString &text) {
        return QStringLiteral("- [%1] %2 · %3").arg(done ? "x" : " ", stamp, text);
    });
}

bool Notes::edit(int line, const QString &text) {
    const QString trimmed = QString(text).replace('\n', ' ').trimmed();
    if (trimmed.isEmpty())
        return remove(line);
    return changeItem(line, [&trimmed](bool done, const QString &stamp, const QString &) {
        return QStringLiteral("- [%1] %2 · %3").arg(done ? "x" : " ", stamp, trimmed);
    });
}

bool Notes::remove(int line) {
    return changeItem(line, [](bool, const QString &, const QString &) { return QString(); });
}

bool Notes::undo() {
    if (m_undo.isEmpty())
        return false;
    const bool ok = writeLines(m_undo.takeLast());
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

// The watcher also fires for the app's own saves, a moment later. Reloading
// then would rebuild the list under whatever the user is doing (an open
// editor, the current row), so only reload when the file really differs.
void Notes::externalChange() {
    if (readLines() == m_lines)
        watch();
    else
        reload();
}

void Notes::reload() {
    watch();
    const QStringList lines = readLines();
    m_lines = lines;
    const QDate today = QDate::currentDate();
    QVariantList items;
    int openCount = 0;
    // Newest first: what was just dumped is what the user most likely wants.
    for (int i = lines.size() - 1; i >= 0; --i) {
        const auto match = itemPattern().match(lines[i]);
        if (!match.hasMatch())
            continue;
        const QDateTime when = QDateTime::fromString(match.captured(2), timeFormat);
        const QDate date = when.date();
        const QString day = date == today ? tr("Today")
                          : date == today.addDays(-1) ? tr("Yesterday")
                          : date.year() == today.year() ? QLocale().toString(date, "ddd, d MMM")
                          : QLocale().toString(date, "ddd, d MMM yyyy");
        const bool done = match.captured(1) != " ";
        if (!done)
            ++openCount;
        items << QVariantMap{{"line", i},
                             {"text", match.captured(3)},
                             {"time", QLocale().toString(when.time(), QLocale::ShortFormat)},
                             {"day", day},
                             {"done", done}};
    }
    m_items = items;
    m_openCount = openCount;
    emit changed();
}
