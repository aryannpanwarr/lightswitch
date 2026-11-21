// lightswitch — dump a thought in a second, then get back to work.
//
// The app stays resident with its window hidden, so summoning it is a show,
// not a launch. `lightswitch` (what the keybinding runs) pokes the resident
// copy over a Unix socket before Qt even starts, and only falls back to
// starting the full app when nothing is listening.

#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include "notes.h"
#include "theme.h"
#include "translator.h"

static std::string socketPath() {
    const char *runtime = std::getenv("XDG_RUNTIME_DIR");
    return std::string(runtime && *runtime ? runtime : "/tmp") + "/lightswitch.sock";
}

// Plain POSIX on purpose: this is the hot path behind the keybinding, and it
// must not wait for Qt to initialise.
static bool sendToResident(const char *command) {
    const std::string path = socketPath();
    const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0)
        return false;
    sockaddr_un address{};
    address.sun_family = AF_UNIX;
    std::strncpy(address.sun_path, path.c_str(), sizeof(address.sun_path) - 1);
    bool ok = connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) == 0;
    if (ok) {
        const std::string line = std::string(command) + "\n";
        ok = write(fd, line.data(), line.size()) == static_cast<ssize_t>(line.size());
    }
    close(fd);
    return ok;
}

// Relays socket commands to the window.
class Ipc : public QObject {
    Q_OBJECT
public:
    bool listen() {
        const QString path = QString::fromStdString(socketPath());
        QLocalServer::removeServer(path);
        m_server.setSocketOptions(QLocalServer::UserAccessOption);
        if (!m_server.listen(path))
            return false;
        connect(&m_server, &QLocalServer::newConnection, this, [this] {
            while (QLocalSocket *client = m_server.nextPendingConnection()) {
                connect(client, &QLocalSocket::readyRead, this, [this, client] {
                    while (client->canReadLine()) {
                        const QByteArray command = client->readLine().trimmed();
                        if (command == "toggle") emit toggleRequested();
                        else if (command == "show") emit showRequested();
                        else if (command == "open" || command == "later") emit openRequested();
                        else if (command == "quit") QCoreApplication::quit();
                    }
                });
                connect(client, &QLocalSocket::disconnected, client, &QObject::deleteLater);
            }
        });
        return true;
    }

signals:
    void toggleRequested();
    void showRequested();
    void openRequested();

private:
    QLocalServer m_server;
};

static int usage(FILE *out) {
    std::fputs("Usage: lightswitch [command]\n\n"
               "  (none), toggle   show or hide the capture window (starts it if needed)\n"
               "  open             open the notes window\n"
               "  daemon           start resident with the window hidden (for autostart)\n"
               "  add <text>       save a note without opening the window\n"
               "  list [--json]    print open notes\n"
               "  path             print the notes file path\n"
               "  quit             stop the resident app\n",
               out);
    return out == stdout ? 0 : 1;
}

static int runHeadless(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    const QStringList args = app.arguments().mid(1);
    const QString command = args.value(0);
    Notes notes;

    if (command == "path") {
        std::printf("%s\n", qPrintable(notes.path()));
        return 0;
    }
    if (command == "add") {
        const QString text = args.mid(1).join(' ');
        const int saved = notes.capture(text);
        if (saved < 0) {
            std::fprintf(stderr, "%s\n", qPrintable(notes.error()));
            return 1;
        }
        if (saved == 0) {
            std::fputs("Nothing to add\n", stderr);
            return 1;
        }
        return 0;
    }
    // list
    if (args.contains("--json")) {
        QJsonArray items;
        for (const QVariant &item : notes.open())
            items << QJsonObject::fromVariantMap(item.toMap());
        std::printf("%s\n", QJsonDocument(items).toJson(QJsonDocument::Compact).constData());
    } else {
        for (const QVariant &item : notes.open()) {
            const QVariantMap m = item.toMap();
            std::printf("%-10s %-8s %s\n", qPrintable(m["day"].toString()), qPrintable(m["time"].toString()), qPrintable(m["text"].toString()));
        }
    }
    return 0;
}

int main(int argc, char *argv[]) {
    const std::string command = argc > 1 ? argv[1] : "toggle";

    if (command == "-h" || command == "--help" || command == "help")
        return usage(stdout);
    if (command == "add" || command == "list" || command == "path")
        return runHeadless(argc, argv);
    if (command == "toggle" || command == "show" || command == "open" || command == "later" || command == "quit") {
        if (sendToResident(command.c_str()))
            return 0;
        if (command == "quit")
            return 0;
    } else if (command == "daemon") {
        if (sendToResident("noop"))
            return 0;  // Already running.
    } else {
        return usage(stderr);
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName("lightswitch");
    app.setApplicationVersion("0.1.0");
    app.setDesktopFileName("lightswitch");
    app.setWindowIcon(QIcon::fromTheme("lightswitch"));
    // Hiding the window must not end the resident app.
    app.setQuitOnLastWindowClosed(false);

    QQuickStyle::setStyle("Material");

    Translator translator;
    app.installTranslator(&translator);

    Ipc ipc;
    if (!ipc.listen()) {
        std::fprintf(stderr, "lightswitch: couldn't listen on %s\n", socketPath().c_str());
        return 1;
    }

    Theme theme;
    Notes notes;

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("notes", &notes);
    engine.rootContext()->setContextProperty("ipc", &ipc);
    engine.rootContext()->setContextProperty("startVisible", command != "daemon");
    engine.rootContext()->setContextProperty("startMode", QString::fromStdString(command == "open" || command == "later" ? "open" : "capture"));
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}

#include "main.moc"
