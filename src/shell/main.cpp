#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QTimer>
#include <QDebug>
#include <QObject>
#include <QString>
#include <QUrl>

#include <cstdlib>

#include "AppRegistry.h"
#include "FileService.h"
#include "NotificationService.h"
#include "SearchService.h"
#include "SettingsStore.h"
#include "TrashService.h"

// TAHOE_VERSION is provided by the build system (see src/shell/CMakeLists.txt) so the
// version string lives in exactly one place. The fallback keeps standalone builds working.
#ifndef TAHOE_VERSION
#define TAHOE_VERSION "0.1.0"
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Tahoe Shell"));
    app.setOrganizationName(QStringLiteral("Project Tahoe"));
    app.setApplicationVersion(QStringLiteral(TAHOE_VERSION));

    // The shell is a normal desktop session surface. The one extra mode is for verification:
    // it renders the shell once, writes a PNG, and exits, so a build can be checked without a
    // display or a running desktop session (see --screenshot in build_env.md).
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral(
        "Project Tahoe X86 desktop shell. Run without arguments to start the shell."));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption screenshotOption(
        QStringLiteral("screenshot"),
        QStringLiteral("Render the shell once, write a PNG to <file>, and exit."),
        QStringLiteral("file"));
    parser.addOption(screenshotOption);
    parser.process(app);

    // Services are created before the engine so they outlive it during shutdown (locals are
    // destroyed in reverse order, which also means SearchService - which holds pointers to
    // the registry and the filesystem service - is destroyed before them).
    SettingsStore settingsStore;
    AppRegistry appRegistry;
    FileService fileService;
    TrashService trashService;
    NotificationService notificationService;
    SearchService searchService(&appRegistry, &fileService);

    qmlRegisterSingletonInstance("Tahoe.Services", 1, 0, "SettingsStore", &settingsStore);
    qmlRegisterSingletonInstance("Tahoe.Services", 1, 0, "AppRegistry", &appRegistry);
    qmlRegisterSingletonInstance("Tahoe.Services", 1, 0, "FileService", &fileService);
    qmlRegisterSingletonInstance("Tahoe.Services", 1, 0, "TrashService", &trashService);
    qmlRegisterSingletonInstance("Tahoe.Services", 1, 0, "NotificationService",
                                &notificationService);
    qmlRegisterSingletonInstance("Tahoe.Services", 1, 0, "SearchService", &searchService);

    QObject::connect(&settingsStore, &SettingsStore::saveFailed, &app,
                     [](const QString &reason) { qWarning() << "Settings save failed:" << reason; });

    // Startup facts worth knowing when something looks wrong. They are warnings, not errors:
    // the shell still runs without them.
    if (appRegistry.count() == 0)
        qWarning() << "AppRegistry: no usable .desktop entries were found; Spotlight and the "
                      "Dock will only be able to open applications this shell hosts";
    qInfo() << "Tahoe Shell" << TAHOE_VERSION << "starting with" << appRegistry.count()
            << "applications; notifications:" << notificationService.dbusStatus();

    QQmlApplicationEngine engine;

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(EXIT_FAILURE); },
                     Qt::QueuedConnection);

    // The shell QML and its shared token/component/service modules are compiled into the
    // resource system by src/shell/tahoe.qrc, so relative imports resolve inside qrc.
    engine.load(QUrl(QStringLiteral("qrc:/shell/qml/main.qml")));

    if (engine.rootObjects().isEmpty()) {
        qWarning() << "Tahoe Shell: failed to load qrc:/shell/qml/main.qml";
        return EXIT_FAILURE;
    }

    if (parser.isSet(screenshotOption)) {
        const QString target = parser.value(screenshotOption);

        // One full second, so the first layout pass, the clock, and the registry-driven Dock
        // contents are all in place before the frame is captured.
        QTimer::singleShot(1000, &app, [&engine, &app, target]() {
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
            if (!window) {
                qWarning() << "--screenshot: the shell root object is not a window";
                QCoreApplication::exit(EXIT_FAILURE);
                return;
            }

            const QImage frame = window->grabWindow();
            if (frame.isNull() || !frame.save(target)) {
                qWarning() << "--screenshot: could not write" << target;
                QCoreApplication::exit(EXIT_FAILURE);
                return;
            }

            qInfo() << "--screenshot: wrote" << target << frame.width() << "x" << frame.height();
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
