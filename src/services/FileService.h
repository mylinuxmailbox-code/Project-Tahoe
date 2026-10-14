#pragma once

#include <QFileInfo>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

/* Project Tahoe X86 filesystem service.
 *
 * Owns all filesystem access for the shell and for applications we host, so QML never
 * performs raw I/O and every failure has a real error string attached.
 *
 * Conventions:
 *   - Mutating calls return { "ok": bool, "error": QString } and never throw.
 *   - Deleting is routed through TrashService, so "delete" is recoverable by default.
 *     Permanent removal is available but is named exactly that: removePermanently().
 *   - Hidden entries are filtered by the caller's request, not silently.
 */
class FileService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit FileService(QObject *parent = nullptr);

    QString status() const { return m_status; }

    // Directory listing. Entries are sorted directories-first, then case-insensitively.
    Q_INVOKABLE QVariantList list(const QString &path, bool showHidden) const;

    // XDG locations that actually exist on this machine, keyed by display name.
    Q_INVOKABLE QVariantMap locations() const;

    // Single entry details, or empty when the path does not exist.
    Q_INVOKABLE QVariantMap stat(const QString &path) const;

    // Recursive filename search. Symlinked directories are not followed (loop safety) and
    // the result count is capped by maxResults.
    Q_INVOKABLE QVariantList search(const QString &root, const QString &pattern,
                                    int maxResults) const;

    Q_INVOKABLE QVariantMap makeDirectory(const QString &parentPath, const QString &name) const;
    Q_INVOKABLE QVariantMap rename(const QString &path, const QString &newName) const;
    Q_INVOKABLE QVariantMap copy(const QString &source, const QString &destination) const;
    Q_INVOKABLE QVariantMap move(const QString &source, const QString &destination) const;
    Q_INVOKABLE QVariantMap removePermanently(const QString &path) const;

    // Reads a regular file as UTF-8 text. Returns { ok, error, text }. Refuses binary files,
    // unreadable files, and files larger than maxBytes, so a text editor cannot exhaust memory.
    Q_INVOKABLE QVariantMap readText(const QString &path, qint64 maxBytes) const;

    // Writes UTF-8 text atomically (temporary file, then rename), so a failed save never leaves
    // a half-written file. It replaces an existing regular file only; it never writes a folder.
    Q_INVOKABLE QVariantMap writeText(const QString &path, const QString &content) const;

    // Parent directory of a path, for "go up" navigation.
    Q_INVOKABLE QString parentPath(const QString &path) const;

    // True when the path is a directory, so the UI can decide before navigating.
    Q_INVOKABLE bool isDirectory(const QString &path) const;

signals:
    void statusChanged();

private:
    static QVariantMap entryToMap(const QFileInfo &info);
    static void collectMatches(const QString &root, const QString &pattern, int limit,
                               QVariantList *results);
    static QVariantMap failure(const QString &reason);
    static QVariantMap success(const QString &message = QString());
    void setStatus(const QString &status);

    QString m_status;
};
