#include "TrashService.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QTextStream>
#include <QUrl>

TrashService::TrashService(QObject *parent)
    : QObject(parent)
{
    QDir().mkpath(homeTrashDir() + QStringLiteral("/files"));
    QDir().mkpath(homeTrashDir() + QStringLiteral("/info"));
    refresh();
}

QString TrashService::homeTrashDir()
{
    const QString xdgDataHome = QProcessEnvironment::systemEnvironment().value(
        QStringLiteral("XDG_DATA_HOME"),
        QDir::homePath() + QStringLiteral("/.local/share"));

    return xdgDataHome + QStringLiteral("/Trash");
}

QString TrashService::trashPath() const
{
    return homeTrashDir();
}

// The spec requires the original path to be percent-encoded so that newlines and non-ASCII
// characters survive a round trip through the plain-text record.
QString TrashService::encodePath(const QString &path)
{
    return QString::fromUtf8(QUrl::toPercentEncoding(path, "/"));
}

QString TrashService::decodePath(const QString &value)
{
    return QUrl::fromPercentEncoding(value.toUtf8());
}

QString TrashService::uniqueTrashName(const QString &desiredName) const
{
    const QDir filesDir(homeTrashDir() + QStringLiteral("/files"));

    if (!filesDir.exists(desiredName))
        return desiredName;

    const QFileInfo info(desiredName);
    const QString base = info.completeBaseName();
    const QString suffix = info.suffix();

    for (int index = 1; index < 10000; ++index) {
        const QString candidate = suffix.isEmpty()
            ? QStringLiteral("%1.%2").arg(base).arg(index)
            : QStringLiteral("%1.%2.%3").arg(base).arg(index).arg(suffix);

        if (!filesDir.exists(candidate))
            return candidate;
    }

    // Extremely unlikely; fall back to a timestamp rather than failing the operation.
    return QStringLiteral("%1.%2").arg(desiredName)
        .arg(QDateTime::currentMSecsSinceEpoch());
}

QVariantMap TrashService::trash(const QStringList &paths)
{
    QVariantMap result;
    int trashed = 0;
    QStringList failures;

    const QString filesRoot = homeTrashDir() + QStringLiteral("/files");
    const QString infoRoot = homeTrashDir() + QStringLiteral("/info");

    QDir().mkpath(filesRoot);
    QDir().mkpath(infoRoot);

    for (const QString &path : paths) {
        const QFileInfo info(path);

        if (!info.exists()) {
            failures << QStringLiteral("%1 (not found)").arg(info.fileName());
            continue;
        }

        // Trashing something that lives inside the trash would nest it pointlessly.
        if (info.absoluteFilePath().startsWith(homeTrashDir() + QLatin1Char('/'))) {
            failures << QStringLiteral("%1 (already in the trash)").arg(info.fileName());
            continue;
        }

        const QString name = uniqueTrashName(info.fileName());
        const QString parkedPath = filesRoot + QLatin1Char('/') + name;
        const QString infoPath = infoRoot + QLatin1Char('/') + name + QStringLiteral(".trashinfo");

        // Write the record first: if the move then fails, a stale record is harmless and is
        // removed below, whereas a moved file with no record would be unrecoverable.
        QFile infoFile(infoPath);
        if (!infoFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            failures << QStringLiteral("%1 (%2)").arg(info.fileName(), infoFile.errorString());
            continue;
        }

        QTextStream stream(&infoFile);
        stream << QStringLiteral("[Trash Info]\n");
        stream << QStringLiteral("Path=") << encodePath(info.absoluteFilePath()) << '\n';
        stream << QStringLiteral("DeletionDate=")
               << QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss"))
               << '\n';
        infoFile.close();

        // Same filesystem: rename is atomic and instant. Across filesystems it fails, so
        // fall back to a copy that is verified before the original is removed.
        bool moved = QFile::rename(info.absoluteFilePath(), parkedPath);

        if (!moved && info.isDir()) {
            moved = QDir().rename(info.absoluteFilePath(), parkedPath);
        }

        if (!moved) {
            bool copied = false;
            if (info.isDir()) {
                copied = QDir().mkpath(parkedPath);
                if (copied) {
                    QDirIterator it(info.absoluteFilePath(),
                                    QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System,
                                    QDirIterator::Subdirectories);
                    while (it.hasNext()) {
                        it.next();
                        const QFileInfo child = it.fileInfo();
                        const QString relative =
                            QDir(info.absoluteFilePath()).relativeFilePath(child.absoluteFilePath());
                        const QString target = parkedPath + QLatin1Char('/') + relative;
                        if (child.isDir())
                            QDir().mkpath(target);
                        else {
                            QDir().mkpath(QFileInfo(target).absolutePath());
                            copied = QFile::copy(child.absoluteFilePath(), target) && copied;
                        }
                    }
                }
            } else {
                copied = QFile::copy(info.absoluteFilePath(), parkedPath);
            }

            if (copied) {
                const bool removed = info.isDir() ? QDir(info.absoluteFilePath()).removeRecursively()
                                                  : QFile::remove(info.absoluteFilePath());
                if (!removed) {
                    QFile::remove(infoPath);
                    failures << QStringLiteral("%1 (copied, original could not be removed)")
                                    .arg(info.fileName());
                    continue;
                }
            } else {
                QFile::remove(infoPath);
                failures << QStringLiteral("%1 (could not move to the trash)").arg(info.fileName());
                continue;
            }
        }

        ++trashed;
    }

    refresh();

    result.insert(QStringLiteral("ok"), failures.isEmpty());
    result.insert(QStringLiteral("trashed"), trashed);
    result.insert(QStringLiteral("failed"), failures);
    result.insert(QStringLiteral("error"),
                  failures.isEmpty() ? QString() : failures.join(QStringLiteral(", ")));

    if (failures.isEmpty()) {
        setStatus(trashed == 1 ? QStringLiteral("Moved 1 item to the trash")
                               : QStringLiteral("Moved %1 items to the trash").arg(trashed));
    } else {
        setStatus(QStringLiteral("%1 of %2 items could not be moved: %3")
                      .arg(failures.size())
                      .arg(paths.size())
                      .arg(failures.join(QStringLiteral(", "))));
    }

    return result;
}

QVariantMap TrashService::readInfoFile(const QString &infoPath)
{
    QVariantMap record;

    QFile file(infoPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return record;

    QTextStream stream(&file);
    bool inTrashInfo = false;

    while (!stream.atEnd()) {
        const QString line = stream.readLine();

        if (line.startsWith(QLatin1Char('['))) {
            inTrashInfo = (line.trimmed() == QLatin1String("[Trash Info]"));
            continue;
        }

        if (!inTrashInfo)
            continue;

        const int separator = line.indexOf(QLatin1Char('='));
        if (separator <= 0)
            continue;

        const QString key = line.left(separator).trimmed();
        const QString value = line.mid(separator + 1).trimmed();

        if (key == QLatin1String("Path"))
            record.insert(QStringLiteral("originalPath"), decodePath(value));
        else if (key == QLatin1String("DeletionDate"))
            record.insert(QStringLiteral("deletedAt"), value);
    }

    return record;
}

QVariantList TrashService::items() const
{
    QVariantList list;

    const QDir infoDir(homeTrashDir() + QStringLiteral("/info"));
    const QStringList infoFiles = infoDir.entryList({ QStringLiteral("*.trashinfo") },
                                                    QDir::Files, QDir::Name);

    for (const QString &infoFile : infoFiles) {
        const QString infoPath = infoDir.absoluteFilePath(infoFile);

        QString name = infoFile;
        name.chop(QStringLiteral(".trashinfo").size());

        const QString contentPath = homeTrashDir() + QStringLiteral("/files/") + name;
        const QFileInfo contentInfo(contentPath);

        QVariantMap item = readInfoFile(infoPath);
        item.insert(QStringLiteral("name"), name);
        item.insert(QStringLiteral("contentPath"), contentPath);
        item.insert(QStringLiteral("isDir"), contentInfo.isDir());
        item.insert(QStringLiteral("size"), contentInfo.isDir()
                        ? double(directorySize(contentPath))
                        : double(contentInfo.size()));

        // A record with no content means something else removed the file. Report it instead
        // of hiding it, so the count and the list agree.
        item.insert(QStringLiteral("missing"), !contentInfo.exists());

        if (!item.contains(QStringLiteral("originalPath")))
            item.insert(QStringLiteral("originalPath"), QString());

        list.append(item);
    }

    return list;
}

qint64 TrashService::directorySize(const QString &path)
{
    qint64 total = 0;

    QDirIterator it(path, QDir::Files | QDir::NoDotAndDotDot | QDir::System,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }

    return total;
}

QVariantMap TrashService::restore(const QString &name)
{
    QVariantMap result;

    const QString filesRoot = homeTrashDir() + QStringLiteral("/files");
    const QString infoRoot = homeTrashDir() + QStringLiteral("/info");

    const QString contentPath = filesRoot + QLatin1Char('/') + name;
    const QString infoPath = infoRoot + QLatin1Char('/') + name + QStringLiteral(".trashinfo");

    if (!QFileInfo::exists(contentPath)) {
        result.insert(QStringLiteral("ok"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("The content for '%1' is missing from the trash").arg(name));
        return result;
    }

    const QVariantMap record = readInfoFile(infoPath);
    const QString originalPath = record.value(QStringLiteral("originalPath")).toString();

    if (originalPath.isEmpty()) {
        result.insert(QStringLiteral("ok"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("The trash record for '%1' has no original path, so it "
                                     "cannot be restored automatically").arg(name));
        return result;
    }

    // Recreate the parent directory when the original location is gone.
    const QFileInfo originalInfo(originalPath);
    if (!QDir(originalInfo.absolutePath()).exists() && !QDir().mkpath(originalInfo.absolutePath())) {
        result.insert(QStringLiteral("ok"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("Could not recreate %1").arg(originalInfo.absolutePath()));
        return result;
    }

    if (QFileInfo::exists(originalPath)) {
        result.insert(QStringLiteral("ok"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("'%1' already exists at the original location").arg(originalPath));
        return result;
    }

    bool moved = QFile::rename(contentPath, originalPath);
    if (!moved && QFileInfo(contentPath).isDir())
        moved = QDir().rename(contentPath, originalPath);

    if (!moved) {
        result.insert(QStringLiteral("ok"), false);
        result.insert(QStringLiteral("error"), QStringLiteral("Could not restore '%1'").arg(name));
        return result;
    }

    QFile::remove(infoPath);
    refresh();

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("error"), QString());
    result.insert(QStringLiteral("restoredTo"), originalPath);
    setStatus(QStringLiteral("Restored '%1'").arg(name));
    return result;
}

QVariantMap TrashService::empty()
{
    QVariantMap result;
    int removed = 0;
    QStringList failures;

    const QString filesRoot = homeTrashDir() + QStringLiteral("/files");
    const QString infoRoot = homeTrashDir() + QStringLiteral("/info");

    QDir filesDir(filesRoot);
    const QFileInfoList entries = filesDir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot
                                                            | QDir::System | QDir::Hidden);

    for (const QFileInfo &entry : entries) {
        const bool ok = entry.isDir() ? QDir(entry.absoluteFilePath()).removeRecursively()
                                      : QFile::remove(entry.absoluteFilePath());
        if (ok)
            ++removed;
        else
            failures << entry.fileName();

        QFile::remove(infoRoot + QLatin1Char('/') + entry.fileName()
                      + QStringLiteral(".trashinfo"));
    }

    // Remove any orphaned records so the count returns to zero.
    QDir infoDir(infoRoot);
    const QFileInfoList infoEntries = infoDir.entryInfoList({ QStringLiteral("*.trashinfo") },
                                                            QDir::Files | QDir::Hidden);
    for (const QFileInfo &entry : infoEntries)
        QFile::remove(entry.absoluteFilePath());

    refresh();

    result.insert(QStringLiteral("ok"), failures.isEmpty());
    result.insert(QStringLiteral("removed"), removed);
    result.insert(QStringLiteral("error"),
                  failures.isEmpty()
                      ? QString()
                      : QStringLiteral("Could not remove: %1").arg(failures.join(QStringLiteral(", "))));

    setStatus(removed == 0 ? QStringLiteral("The trash was already empty")
                           : QStringLiteral("Permanently removed %1 items").arg(removed));
    return result;
}

void TrashService::refresh()
{
    const QVariantList list = items();

    m_count = list.size();
    m_sizeBytes = 0;
    for (const QVariant &item : list)
        m_sizeBytes += qint64(item.toMap().value(QStringLiteral("size")).toDouble());

    emit countChanged();
}

void TrashService::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}
