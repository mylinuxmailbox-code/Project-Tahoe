#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
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

    return app.exec();
}
