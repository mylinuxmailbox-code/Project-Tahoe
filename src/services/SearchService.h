#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

class AppRegistry;
class FileService;

/* Project Tahoe X86 search service.
 *
 * Backs Spotlight. Every result is actionable and backed by a real service:
 *   - "app"     resolved from installed .desktop entries (AppRegistry)
 *   - "file"    found on the real filesystem (FileService)
 *   - "setting" a shell preference that the Settings application can actually change
 *
 * There is no fuzzy fake relevance model here: results are ranked by an explicit rule
 * (prefix match, then word-boundary match, then substring), and each result carries the
 * identifier the UI needs to act on it. Nothing is returned that cannot be opened.
 */
class SearchService : public QObject
{
    Q_OBJECT

public:
    SearchService(AppRegistry *apps, FileService *files, QObject *parent = nullptr);

    // Unified search. maxResults bounds the total returned.
    Q_INVOKABLE QVariantList search(const QString &query, int maxResults = 12) const;

    // The settings the shell can really change, for browsing with an empty query.
    Q_INVOKABLE QVariantList settingsEntries() const;

private:
    enum MatchRank {
        NoMatch = 0,
        Substring = 1,
        WordStart = 2,
        Prefix = 3,
        Exact = 4
    };

    static MatchRank rank(const QString &haystack, const QString &needle);
    QVariantList rankSettings(const QString &query) const;

    AppRegistry *m_apps = nullptr;
    FileService *m_files = nullptr;
};
