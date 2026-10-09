#include "SearchService.h"

#include "AppRegistry.h"
#include "FileService.h"

#include <QDir>
#include <QFileInfo>
#include <QMultiMap>

SearchService::SearchService(AppRegistry *apps, FileService *files, QObject *parent)
    : QObject(parent)
    , m_apps(apps)
    , m_files(files)
{
}

SearchService::MatchRank SearchService::rank(const QString &haystack, const QString &needle)
{
    if (haystack.isEmpty() || needle.isEmpty())
        return NoMatch;

    const QString lowerHaystack = haystack.toLower();
    const QString lowerNeedle = needle.toLower();

    if (lowerHaystack == lowerNeedle)
        return Exact;

    if (lowerHaystack.startsWith(lowerNeedle))
        return Prefix;

    // A match at the start of any word beats a match in the middle: "te" should find
    // "Text Editor" ahead of "Gigabyte Utility".
    const int substringIndex = lowerHaystack.indexOf(lowerNeedle);
    if (substringIndex > 0) {
        const QChar previous = lowerHaystack.at(substringIndex - 1);
        if (previous == QLatin1Char(' ') || previous == QLatin1Char('-')
            || previous == QLatin1Char('_') || previous == QLatin1Char('.')) {
            return WordStart;
        }
    }

    if (substringIndex >= 0)
        return Substring;

    return NoMatch;
}

QVariantList SearchService::settingsEntries() const
{
    QVariantList entries;

    const auto add = [&entries](const QString &key, const QString &title,
                                const QString &subtitle) {
        QVariantMap entry;
        entry.insert(QStringLiteral("type"), QStringLiteral("setting"));
        entry.insert(QStringLiteral("title"), title);
        entry.insert(QStringLiteral("subtitle"), subtitle);
        entry.insert(QStringLiteral("settingKey"), key);
        entry.insert(QStringLiteral("iconPath"), QString());
        entries.append(entry);
    };

    add(QStringLiteral("appearanceMode"), QStringLiteral("Appearance"),
        QStringLiteral("Switch between light and dark"));
    add(QStringLiteral("wallpaperSource"), QStringLiteral("Wallpaper"),
        QStringLiteral("Choose the desktop background"));
    add(QStringLiteral("dockIconSize"), QStringLiteral("Dock icon size"),
        QStringLiteral("Change how large Dock icons are"));
    add(QStringLiteral("dockPosition"), QStringLiteral("Dock position"),
        QStringLiteral("Move the Dock to another screen edge"));
    add(QStringLiteral("dockMagnification"), QStringLiteral("Dock magnification"),
        QStringLiteral("Enable or disable hover magnification"));
    add(QStringLiteral("dockAutoHide"), QStringLiteral("Dock auto-hide"),
        QStringLiteral("Hide the Dock until the pointer reaches the edge"));
    add(QStringLiteral("reduceMotion"), QStringLiteral("Reduce motion"),
        QStringLiteral("Use shorter, calmer animations"));
    add(QStringLiteral("windowCornerRadius"), QStringLiteral("Window corner radius"),
        QStringLiteral("Change how round window corners are"));

    return entries;
}

QVariantList SearchService::rankSettings(const QString &query) const
{
    QVariantList ranked;
    QMultiMap<int, QVariant> byRank;

    const QVariantList settings = settingsEntries();
    for (const QVariant &value : settings) {
        const QVariantMap entry = value.toMap();
        const MatchRank titleRank = rank(entry.value(QStringLiteral("title")).toString(), query);
        const MatchRank keyRank = rank(entry.value(QStringLiteral("settingKey")).toString(), query);
        const MatchRank best = titleRank > keyRank ? titleRank : keyRank;

        if (best != NoMatch)
            byRank.insert(int(best), entry);
    }

    // Highest rank last in QMultiMap, so iterate in reverse for best-first ordering.
    for (auto it = byRank.constEnd(); it != byRank.constBegin();) {
        --it;
        ranked.append(it.value());
    }

    return ranked;
}

QVariantList SearchService::search(const QString &query, int maxResults) const
{
    QVariantList results;

    const QString trimmed = query.trimmed();
    if (trimmed.isEmpty() || maxResults <= 0)
        return results;

    // Applications and settings are cheap and always searched. Filesystem search is the
    // expensive one, so it only runs for a real query and gets whatever budget is left.
    if (m_apps) {
        const QVariantList apps = m_apps->toVariantList();

        QMultiMap<int, QVariant> ranked;
        for (const QVariant &value : apps) {
            const QVariantMap app = value.toMap();
            const QString name = app.value(QStringLiteral("name")).toString();
            const MatchRank best = rank(name, trimmed);
            if (best == NoMatch)
                continue;

            QVariantMap entry;
            entry.insert(QStringLiteral("type"), QStringLiteral("app"));
            entry.insert(QStringLiteral("title"), name);
            entry.insert(QStringLiteral("subtitle"),
                         app.value(QStringLiteral("comment")).toString());
            entry.insert(QStringLiteral("iconPath"),
                         app.value(QStringLiteral("iconPath")).toString());
            entry.insert(QStringLiteral("desktopId"),
                         app.value(QStringLiteral("desktopId")).toString());
            ranked.insert(int(best), entry);
        }

        for (auto it = ranked.constEnd(); it != ranked.constBegin();) {
            --it;
            results.append(it.value());
            if (results.size() >= maxResults)
                return results;
        }
    }

    // Settings only make sense for short queries: nobody types a filename that matches
    // "appearance", and it keeps the list focused.
    if (trimmed.size() <= 24) {
        const QVariantList settings = rankSettings(trimmed);
        for (const QVariant &entry : settings) {
            results.append(entry);
            if (results.size() >= maxResults)
                return results;
        }
    }

    if (m_files && trimmed.size() >= 2) {
        const int remaining = maxResults - results.size();
        const QVariantList files = m_files->search(QDir::homePath(), trimmed, remaining);

        for (const QVariant &value : files) {
            const QVariantMap file = value.toMap();

            QVariantMap entry;
            entry.insert(QStringLiteral("type"), QStringLiteral("file"));
            entry.insert(QStringLiteral("title"), file.value(QStringLiteral("name")));
            entry.insert(QStringLiteral("path"), file.value(QStringLiteral("path")));
            entry.insert(QStringLiteral("isDir"), file.value(QStringLiteral("isDir")));
            entry.insert(QStringLiteral("subtitle"),
                         QFileInfo(file.value(QStringLiteral("path")).toString()).absolutePath());
            entry.insert(QStringLiteral("iconPath"), QString());
            results.append(entry);

            if (results.size() >= maxResults)
                return results;
        }
    }

    return results;
}
