#include <QtTest>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "AppRegistry.h"
#include "FileService.h"
#include "NotificationService.h"
#include "SettingsStore.h"

/* Project Tahoe X86 service tests.
 *
 * These are behavioural tests, not structural ones. Each one calls a real service and checks
 * the documented contract — including the contracts that are about honesty rather than
 * success, such as "a missing settings file is defaults in use, not an error" and "a failed
 * file operation returns a real error string".
 *
 * They run without a desktop session (QTEST_GUILESS_MAIN) and without touching the user's own
 * configuration or files: the settings tests point XDG_CONFIG_HOME at a temporary directory
 * and the filesystem tests work inside another one.
 */

class TestServices : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();

    // SettingsStore — persistence and failure reporting
    void settingsMissingFileMeansDefaults();
    void settingsRoundTripThroughDisk();
    void settingsInvalidFileIsReportedAndNotOverwritten();

    // FileService — real filesystem operations
    void fileServiceCreatesListsAndStats();
    void fileServiceRenamesAndSearches();
    void fileServiceFailuresCarryAnError();

    // NotificationService — the real model behind the Notification Centre
    void notificationRaiseDismissAndClear();

    // AppRegistry — the .desktop scan and icon resolution
    void appRegistryScanIsSelfConsistent();
    void appRegistryResolvesOnlyIconsThatExist();

private:
    QTemporaryDir *m_configHome = nullptr;
    QTemporaryDir *m_work = nullptr;
};

void TestServices::initTestCase()
{
    m_configHome = new QTemporaryDir();
    QVERIFY2(m_configHome->isValid(), "could not create a temporary configuration directory");

    m_work = new QTemporaryDir();
    QVERIFY2(m_work->isValid(), "could not create a temporary working directory");

    // SettingsStore resolves its directory from the environment in its constructor, so this has
    // to happen before any store is created, and it is why each settings test makes its own.
    qputenv("XDG_CONFIG_HOME", m_configHome->path().toUtf8());
}

void TestServices::cleanupTestCase()
{
    delete m_configHome;
    m_configHome = nullptr;
    delete m_work;
    m_work = nullptr;
}

// --------------------------------------------------------------------------- SettingsStore

void TestServices::settingsMissingFileMeansDefaults()
{
    SettingsStore store;
    QVERIFY2(store.available(), qPrintable(store.status()));
    QVERIFY(store.configPath().startsWith(m_configHome->path()));
    QVERIFY(!QFile::exists(store.configPath()));

    // A missing file is the normal first run. It must not be reported as a failure.
    QSignalSpy loadFailed(&store, &SettingsStore::loadFailed);
    const QVariantMap values = store.load();

    QVERIFY(values.isEmpty());
    QCOMPARE(loadFailed.count(), 0);
    QVERIFY(store.status().contains(QStringLiteral("Defaults in use")));
}

void TestServices::settingsRoundTripThroughDisk()
{
    SettingsStore store;

    QVariantList pinned;
    pinned << QVariantMap{ { QStringLiteral("id"), QStringLiteral("finder") },
                           { QStringLiteral("label"), QStringLiteral("Finder") } };
    pinned << QVariantMap{ { QStringLiteral("id"), QStringLiteral("settings") },
                           { QStringLiteral("label"), QStringLiteral("Settings") } };

    QVariantMap values;
    values.insert(QStringLiteral("appearanceMode"), QStringLiteral("light"));
    values.insert(QStringLiteral("reduceMotion"), true);
    values.insert(QStringLiteral("dockPinnedApps"), pinned);

    QSignalSpy saveFailed(&store, &SettingsStore::saveFailed);
    QVERIFY(store.save(values));
    QCOMPARE(saveFailed.count(), 0);
    QVERIFY(QFile::exists(store.configPath()));

    // A second instance must see exactly what the first one wrote, nested structures included.
    SettingsStore reloaded;
    const QVariantMap loaded = reloaded.load();

    QCOMPARE(loaded.value(QStringLiteral("appearanceMode")).toString(), QStringLiteral("light"));
    QCOMPARE(loaded.value(QStringLiteral("reduceMotion")).toBool(), true);

    const QVariantList pinnedBack = loaded.value(QStringLiteral("dockPinnedApps")).toList();
    QCOMPARE(pinnedBack.size(), 2);
    QCOMPARE(pinnedBack.at(0).toMap().value(QStringLiteral("id")).toString(),
             QStringLiteral("finder"));
    QCOMPARE(pinnedBack.at(1).toMap().value(QStringLiteral("label")).toString(),
             QStringLiteral("Settings"));
    QVERIFY(reloaded.status().contains(QStringLiteral("Loaded")));
}

void TestServices::settingsInvalidFileIsReportedAndNotOverwritten()
{
    SettingsStore store;

    const QByteArray garbage("{ this is not json");
    QFile file(store.configPath());
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
    QCOMPARE(file.write(garbage), qint64(garbage.size()));
    file.close();

    QSignalSpy loadFailed(&store, &SettingsStore::loadFailed);
    const QVariantMap values = store.load();

    QVERIFY(values.isEmpty());
    QCOMPARE(loadFailed.count(), 1);
    QVERIFY(store.status().contains(QStringLiteral("Defaults in use")));

    // The documented contract: a broken file is reported, and reading it never rewrites or
    // removes it. Losing a user's file because it failed to parse would be the worst outcome.
    QVERIFY(file.open(QIODevice::ReadOnly));
    QCOMPARE(file.readAll(), garbage);
    file.close();
}

// --------------------------------------------------------------------------- FileService

void TestServices::fileServiceCreatesListsAndStats()
{
    FileService service;

    const QString dir = m_work->path() + QStringLiteral("/scratch");
    QVERIFY(QDir().mkpath(dir));

    QFile probe(dir + QStringLiteral("/notes.txt"));
    QVERIFY(probe.open(QIODevice::WriteOnly));
    QCOMPARE(probe.write("hello"), qint64(5));
    probe.close();

    QVERIFY(QDir(dir).mkdir(QStringLiteral("subfolder")));

    const QVariantList entries = service.list(dir, false);
    // "." and ".." are filtered, so exactly the two entries that were created.
    QCOMPARE(entries.size(), 2);

    // Directories first is documented behaviour, and the Finder relies on it.
    QCOMPARE(entries.at(0).toMap().value(QStringLiteral("name")).toString(),
             QStringLiteral("subfolder"));
    QVERIFY(entries.at(0).toMap().value(QStringLiteral("isDir")).toBool());
    QCOMPARE(entries.at(1).toMap().value(QStringLiteral("name")).toString(),
             QStringLiteral("notes.txt"));
    QVERIFY(!entries.at(1).toMap().value(QStringLiteral("isDir")).toBool());

    const QVariantMap info = service.stat(dir + QStringLiteral("/notes.txt"));
    QCOMPARE(info.value(QStringLiteral("name")).toString(), QStringLiteral("notes.txt"));
    QCOMPARE(info.value(QStringLiteral("size")).toDouble(), 5.0);
    QVERIFY(info.value(QStringLiteral("isReadable")).toBool());

    // A path that does not exist is an empty map, not a made-up entry.
    QVERIFY(service.stat(dir + QStringLiteral("/no-such-file")).isEmpty());
    QVERIFY(service.list(dir + QStringLiteral("/no-such-dir"), false).isEmpty());
}

void TestServices::fileServiceRenamesAndSearches()
{
    FileService service;
    const QString dir = m_work->path() + QStringLiteral("/scratch");

    const QVariantMap renamed = service.rename(dir + QStringLiteral("/notes.txt"),
                                               QStringLiteral("renamed.txt"));
    QVERIFY2(renamed.value(QStringLiteral("ok")).toBool(),
             qPrintable(renamed.value(QStringLiteral("error")).toString()));
    QVERIFY(QFile::exists(dir + QStringLiteral("/renamed.txt")));
    QVERIFY(!QFile::exists(dir + QStringLiteral("/notes.txt")));

    const QVariantList found = service.search(dir, QStringLiteral("renamed"), 10);
    QCOMPARE(found.size(), 1);
    QCOMPARE(found.at(0).toMap().value(QStringLiteral("name")).toString(),
             QStringLiteral("renamed.txt"));

    // No match returns an empty list. It is not an error and it is not a guess.
    QVERIFY(service.search(dir, QStringLiteral("no-such-name-anywhere"), 10).isEmpty());

    // The limit is honoured, so a search cannot walk a whole home directory unbounded.
    QVERIFY(service.search(dir, QStringLiteral("e"), 1).size() <= 1);
}

void TestServices::fileServiceFailuresCarryAnError()
{
    FileService service;
    const QString missing = m_work->path() + QStringLiteral("/not-here.txt");

    const QVariantMap renamed = service.rename(missing, QStringLiteral("x.txt"));
    QCOMPARE(renamed.value(QStringLiteral("ok")).toBool(), false);
    QVERIFY(!renamed.value(QStringLiteral("error")).toString().isEmpty());

    const QVariantMap copied = service.copy(missing, m_work->path() + QStringLiteral("/x.txt"));
    QCOMPARE(copied.value(QStringLiteral("ok")).toBool(), false);
    QVERIFY(!copied.value(QStringLiteral("error")).toString().isEmpty());

    const QVariantMap removed = service.removePermanently(missing);
    QCOMPARE(removed.value(QStringLiteral("ok")).toBool(), false);
    QVERIFY(!removed.value(QStringLiteral("error")).toString().isEmpty());
}

// --------------------------------------------------------------------------- NotificationService

void TestServices::notificationRaiseDismissAndClear()
{
    NotificationService service;
    const int before = service.count();

    const uint id = service.notify(QStringLiteral("Tahoe Shell"),
                                   QStringLiteral("Test summary"),
                                   QStringLiteral("Test body"), 1);

    QVERIFY(id != 0);
    QCOMPARE(service.count(), before + 1);
    QVERIFY(service.unreadCount() >= 1);
    QCOMPARE(service.latestSummary(), QStringLiteral("Test summary"));

    service.dismiss(id);
    QCOMPARE(service.count(), before);

    service.notify(QStringLiteral("Tahoe Shell"), QStringLiteral("One"), QString(), 1);
    service.notify(QStringLiteral("Tahoe Shell"), QStringLiteral("Two"), QString(), 2);
    QCOMPARE(service.count(), before + 2);

    service.dismissAll();
    QCOMPARE(service.count(), 0);
    QCOMPARE(service.unreadCount(), 0);
}

// --------------------------------------------------------------------------- AppRegistry

void TestServices::appRegistryScanIsSelfConsistent()
{
    AppRegistry registry;

    QVERIFY(!registry.status().isEmpty());
    QCOMPARE(registry.toVariantList().size(), registry.count());
    QCOMPARE(registry.rowCount(), registry.count());

    // Broken entries are counted and reported rather than hidden, so the two numbers together
    // account for every .desktop file the scan looked at.
    QVERIFY(registry.brokenCount() >= 0);

    if (registry.count() > 0) {
        const QVariantMap first = registry.toVariantList().at(0).toMap();
        QVERIFY(!first.value(QStringLiteral("desktopId")).toString().isEmpty());
        QVERIFY(!first.value(QStringLiteral("name")).toString().isEmpty());

        // The list model and the plain-list accessor have to agree, because the Dock reads the
        // list and Spotlight reads the model.
        const QModelIndex index = registry.index(0, 0);
        QVERIFY(index.isValid());
        QCOMPARE(registry.data(index, AppRegistry::NameRole).toString(),
                 first.value(QStringLiteral("name")).toString());
        QCOMPARE(registry.data(index, AppRegistry::IdRole).toString(),
                 first.value(QStringLiteral("desktopId")).toString());
    }
}

void TestServices::appRegistryResolvesOnlyIconsThatExist()
{
    AppRegistry registry;

    // Either a real file on disk or nothing: never a path that cannot be opened. Which one it
    // is depends on the icon themes installed, so the assertion is the contract, not the name.
    const QString resolved = registry.resolveIcon(QStringLiteral("system-file-manager"));
    if (!resolved.isEmpty())
        QVERIFY2(QFileInfo::exists(resolved), qPrintable(resolved));

    // A name that cannot exist resolves to nothing rather than to a substitute.
    QVERIFY(registry.resolveIcon(QStringLiteral("tahoe-no-such-icon-4f6a1c")).isEmpty());
    QVERIFY(registry.resolveIcon(QString()).isEmpty());
}

QTEST_GUILESS_MAIN(TestServices)
#include "tst_services.moc"
