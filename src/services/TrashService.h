#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

/* Project Tahoe X86 trash service.
 *
 * Implements the freedesktop.org Trash specification for the home trash directory:
 *
 *   $XDG_DATA_HOME/Trash/files/   the deleted content
 *   $XDG_DATA_HOME/Trash/info/    <name>.trashinfo records
 *
 * A .trashinfo record stores the original absolute path and the deletion date, which is
 * what makes restore work and what lets other file managers (Nautilus, Dolphin, and the
 * `gio trash` CLI) see and restore the same items. Writing our own private trash folder
 * would have looked like deleting, but the content would have been unrecoverable by
 * anything except this shell.
 *
 * Failure policy: a failed trash operation leaves the original file untouched and reports
 * the real reason. Nothing here deletes first and reports afterwards.
 */
class TrashService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString trashPath READ trashPath CONSTANT)

    // Bytes currently held in the trash, for the "Empty Trash" confirmation.
    Q_PROPERTY(qint64 sizeBytes READ sizeBytes NOTIFY countChanged)

public:
    explicit TrashService(QObject *parent = nullptr);

    int count() const { return m_count; }
    QString status() const { return m_status; }
    QString trashPath() const;
    qint64 sizeBytes() const { return m_sizeBytes; }

    // Move each path to the trash. Returns { ok, error, trashed: int, failed: [names] }.
    // Partial success is reported honestly: the count and the failures are separate fields.
    Q_INVOKABLE QVariantMap trash(const QStringList &paths);

    // Current contents, newest first: { name, originalPath, deletedAt, isDir, size }.
    Q_INVOKABLE QVariantList items() const;

    // Restore one item by its trash file name. Returns { ok, error, restoredTo }.
    Q_INVOKABLE QVariantMap restore(const QString &name);

    // Permanently remove everything in the trash. Returns { ok, error, removed: int }.
    Q_INVOKABLE QVariantMap empty();

    // Rescan the trash directory and refresh count/size.
    Q_INVOKABLE void refresh();

signals:
    void countChanged();
    void statusChanged();

private:
    static QString homeTrashDir();
    static QString encodePath(const QString &path);
    static QString decodePath(const QString &value);
    static QVariantMap readInfoFile(const QString &infoPath);
    QString uniqueTrashName(const QString &desiredName) const;
    static qint64 directorySize(const QString &path);
    void setStatus(const QString &status);

    int m_count = 0;
    qint64 m_sizeBytes = 0;
    QString m_status;
};
