#include "FileService.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QDateTime>

#include <algorithm>

FileService::FileService(QObject *parent)
    : QObject(parent)
{
    setStatus(QStringLiteral("Filesystem access ready"));
}

QVariantMap FileService::entryToMap(const QFileInfo &info)
{
    QVariantMap entry;
    entry.insert(QStringLiteral("name"), info.fileName());
    entry.insert(QStringLiteral("path"), info.absoluteFilePath());
    entry.insert(QStringLiteral("isDir"), info.isDir());
    entry.insert(QStringLiteral("isSymlink"), info.isSymLink());
    entry.insert(QStringLiteral("isHidden"), info.isHidden());
    entry.insert(QStringLiteral("isExecutable"), info.isExecutable());
    entry.insert(QStringLiteral("size"), info.isDir() ? 0.0 : double(info.size()));
    entry.insert(QStringLiteral("modified"),
                 info.lastModified().toString(Qt::ISODate));
    entry.insert(QStringLiteral("isReadable"), info.isReadable());
    entry.insert(QStringLiteral("isWritable"), info.isWritable());

    if (info.isSymLink()) {
        const QString target = info.symLinkTarget();
        entry.insert(QStringLiteral("linkTarget"), target);
        entry.insert(QStringLiteral("brokenLink"), target.isEmpty() || !QFileInfo::exists(target));
    } else {
        entry.insert(QStringLiteral("linkTarget"), QString());
        entry.insert(QStringLiteral("brokenLink"), false);
    }

    return entry;
}

QVariantList FileService::list(const QString &path, bool showHidden) const
{
    QVariantList result;

    QDir dir(path);
    if (!dir.exists())
        return result;

    QFileInfoList entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot
                                                  | QDir::System,
                                              QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);

    for (const QFileInfo &info : entries) {
        if (!showHidden && info.isHidden())
            continue;
        result.append(entryToMap(info));
    }

    return result;
}

QVariantMap FileService::locations() const
{
    QVariantMap map;

    const auto add = [&map](const QString &label, const QString &path) {
        if (!path.isEmpty() && QFileInfo(path).isDir())
            map.insert(label, path);
    };

    add(QStringLiteral("Home"), QDir::homePath());
    add(QStringLiteral("Desktop"), QStandardPaths::writableLocation(QStandardPaths::DesktopLocation));
    add(QStringLiteral("Documents"), QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation));
    add(QStringLiteral("Downloads"), QStandardPaths::writableLocation(QStandardPaths::DownloadLocation));
    add(QStringLiteral("Music"), QStandardPaths::writableLocation(QStandardPaths::MusicLocation));
    add(QStringLiteral("Pictures"), QStandardPaths::writableLocation(QStandardPaths::PicturesLocation));
    add(QStringLiteral("Videos"), QStandardPaths::writableLocation(QStandardPaths::MoviesLocation));
    add(QStringLiteral("Applications"), QStringLiteral("/usr/share/applications"));
    add(QStringLiteral("Root"), QStringLiteral("/"));

    return map;
}

QVariantMap FileService::stat(const QString &path) const
{
    const QFileInfo info(path);
    if (!info.exists())
        return QVariantMap();

    return entryToMap(info);
}

void FileService::collectMatches(const QString &root, const QString &pattern, int limit,
                                 QVariantList *results)
{
    if (results->size() >= limit)
        return;

    // No FollowSymlinks flag: the default is to report symlinks without descending into
    // them, which is what a bounded search over a user directory needs.
    QDirIterator it(root, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System,
                    QDirIterator::Subdirectories);

    while (it.hasNext() && results->size() < limit) {
        it.next();
        const QFileInfo info = it.fileInfo();

        if (info.fileName().contains(pattern, Qt::CaseInsensitive))
            results->append(entryToMap(info));
    }
}

QVariantList FileService::search(const QString &root, const QString &pattern,
                                 int maxResults) const
{
    QVariantList results;

    if (pattern.isEmpty() || maxResults <= 0)
        return results;

    if (!QFileInfo(root).isDir())
        return results;

    collectMatches(root, pattern, maxResults, &results);

    std::sort(results.begin(), results.end(),
              [](const QVariant &a, const QVariant &b) {
                  const QVariantMap left = a.toMap();
                  const QVariantMap right = b.toMap();
                  const bool leftDir = left.value(QStringLiteral("isDir")).toBool();
                  const bool rightDir = right.value(QStringLiteral("isDir")).toBool();
                  if (leftDir != rightDir)
                      return leftDir;
                  return left.value(QStringLiteral("name")).toString().toLower()
                      < right.value(QStringLiteral("name")).toString().toLower();
              });

    return results;
}

QVariantMap FileService::failure(const QString &reason)
{
    QVariantMap map;
    map.insert(QStringLiteral("ok"), false);
    map.insert(QStringLiteral("error"), reason);
    return map;
}

QVariantMap FileService::success(const QString &message)
{
    QVariantMap map;
    map.insert(QStringLiteral("ok"), true);
    map.insert(QStringLiteral("error"), QString());
    map.insert(QStringLiteral("message"), message);
    return map;
}

QVariantMap FileService::makeDirectory(const QString &parentPath, const QString &name) const
{
    if (name.trimmed().isEmpty())
        return failure(QStringLiteral("A folder name is required"));

    if (name.contains(QLatin1Char('/')))
        return failure(QStringLiteral("A folder name cannot contain '/' "));

    QDir parent(parentPath);
    if (!parent.exists())
        return failure(QStringLiteral("Folder does not exist: %1").arg(parentPath));

    if (parent.exists(name))
        return failure(QStringLiteral("'%1' already exists here").arg(name));

    if (!parent.mkdir(name))
        return failure(QStringLiteral("Could not create '%1' in %2").arg(name, parentPath));

    return success(QStringLiteral("Created '%1'").arg(name));
}

QVariantMap FileService::rename(const QString &path, const QString &newName) const
{
    if (newName.trimmed().isEmpty())
        return failure(QStringLiteral("A new name is required"));

    if (newName.contains(QLatin1Char('/')))
        return failure(QStringLiteral("A name cannot contain '/' "));

    const QFileInfo info(path);
    if (!info.exists())
        return failure(QStringLiteral("No such file or folder: %1").arg(path));

    if (info.fileName() == newName)
        return success(QStringLiteral("Name unchanged"));

    QDir parent(info.absolutePath());
    if (parent.exists(newName))
        return failure(QStringLiteral("'%1' already exists here").arg(newName));

    if (!QFile::rename(info.absoluteFilePath(), parent.absoluteFilePath(newName)))
        return failure(QStringLiteral("Could not rename '%1'").arg(info.fileName()));

    return success(QStringLiteral("Renamed to '%1'").arg(newName));
}

QVariantMap FileService::copy(const QString &source, const QString &destination) const
{
    const QFileInfo sourceInfo(source);
    if (!sourceInfo.exists())
        return failure(QStringLiteral("Nothing to copy at %1").arg(source));

    const QFileInfo destinationInfo(destination);

    // Copying into an existing directory means "put it inside", which is what a file
    // manager does when you drop an item onto a folder.
    QString target = destination;
    if (destinationInfo.isDir())
        target = destinationInfo.absoluteFilePath() + QLatin1Char('/') + sourceInfo.fileName();

    if (QFileInfo::exists(target))
        return failure(QStringLiteral("'%1' already exists at the destination")
                           .arg(QFileInfo(target).fileName()));

    if (sourceInfo.isDir()) {
        QDir sourceDir(source);
        if (!QDir().mkpath(target))
            return failure(QStringLiteral("Could not create %1").arg(target));

        // Recursive copy that reports the first failure instead of silently skipping.
        QDirIterator it(source, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System,
                        QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            const QFileInfo info = it.fileInfo();
            const QString relative = sourceDir.relativeFilePath(info.absoluteFilePath());
            const QString targetPath = target + QLatin1Char('/') + relative;

            if (info.isDir()) {
                if (!QDir().mkpath(targetPath))
                    return failure(QStringLiteral("Could not create %1").arg(targetPath));
            } else {
                QDir().mkpath(QFileInfo(targetPath).absolutePath());
                if (!QFile::copy(info.absoluteFilePath(), targetPath))
                    return failure(QStringLiteral("Could not copy %1").arg(relative));
            }
        }
    } else if (!QFile::copy(sourceInfo.absoluteFilePath(), target)) {
        return failure(QStringLiteral("Could not copy '%1'").arg(sourceInfo.fileName()));
    }

    return success(QStringLiteral("Copied '%1'").arg(sourceInfo.fileName()));
}

QVariantMap FileService::move(const QString &source, const QString &destination) const
{
    const QFileInfo sourceInfo(source);
    if (!sourceInfo.exists())
        return failure(QStringLiteral("Nothing to move at %1").arg(source));

    const QFileInfo destinationInfo(destination);
    QString target = destination;
    if (destinationInfo.isDir())
        target = destinationInfo.absoluteFilePath() + QLatin1Char('/') + sourceInfo.fileName();

    if (QFileInfo::exists(target))
        return failure(QStringLiteral("'%1' already exists at the destination")
                           .arg(QFileInfo(target).fileName()));

    // QFile::rename handles both plain renames and same-filesystem moves. Across
    // filesystems it fails, so fall back to copy-then-remove rather than pretending.
    if (QFile::rename(sourceInfo.absoluteFilePath(), target))
        return success(QStringLiteral("Moved '%1'").arg(sourceInfo.fileName()));

    const QVariantMap copyResult = copy(source, target);
    if (!copyResult.value(QStringLiteral("ok")).toBool())
        return copyResult;

    const QVariantMap removeResult = removePermanently(source);
    if (!removeResult.value(QStringLiteral("ok")).toBool()) {
        return failure(QStringLiteral("Copied, but could not remove the original: %1")
                           .arg(removeResult.value(QStringLiteral("error")).toString()));
    }

    return success(QStringLiteral("Moved '%1'").arg(sourceInfo.fileName()));
}

QVariantMap FileService::removePermanently(const QString &path) const
{
    const QFileInfo info(path);
    if (!info.exists())
        return failure(QStringLiteral("Nothing to remove at %1").arg(path));

    const bool removed = info.isDir() ? QDir(path).removeRecursively() : QFile::remove(path);
    if (!removed)
        return failure(QStringLiteral("Could not remove '%1'").arg(info.fileName()));

    return success(QStringLiteral("Removed '%1'").arg(info.fileName()));
}

QString FileService::parentPath(const QString &path) const
{
    const QFileInfo info(path);
    if (info.absolutePath() == path)
        return path;

    return info.absolutePath();
}

bool FileService::isDirectory(const QString &path) const
{
    return QFileInfo(path).isDir();
}

void FileService::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}
