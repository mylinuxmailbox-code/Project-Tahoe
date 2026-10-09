#include "AppRegistry.h"

#include <algorithm>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>
#include <QProcessEnvironment>

namespace {

// Reads the [Desktop Entry] group of a .desktop file into a key/value map.
// Writing a parser instead of using QSettings is deliberate: .desktop keys may contain
// characters QSettings interprets as group separators or array markers (Name[en], etc.).
QHash<QString, QString> readDesktopEntry(const QString &path)
{
    QHash<QString, QString> values;

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return values;

    QTextStream stream(&file);
    bool inEntryGroup = false;

    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();

        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;

        if (line.startsWith(QLatin1Char('['))) {
            inEntryGroup = (line == QLatin1String("[Desktop Entry]"));
            continue;
        }

        if (!inEntryGroup)
            continue;

        const int separator = line.indexOf(QLatin1Char('='));
        if (separator <= 0)
            continue;

        const QString key = line.left(separator).trimmed();
        const QString value = line.mid(separator + 1).trimmed();

        // Keep the unlocalised value: a localised key such as Name[en_GB] must not
        // overwrite the plain Name key.
        if (!key.contains(QLatin1Char('[')))
            values.insert(key, value);
    }

    return values;
}

bool isTruthy(const QString &value)
{
    return value.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0;
}

} // namespace

AppRegistry::AppRegistry(QObject *parent)
    : QObject(parent)
{
    refresh();
}

QStringList AppRegistry::applicationDirs()
{
    QStringList dirs;

    const QString xdgDataHome = QProcessEnvironment::systemEnvironment().value(
        QStringLiteral("XDG_DATA_HOME"),
        QDir::homePath() + QStringLiteral("/.local/share"));
    dirs << xdgDataHome + QStringLiteral("/applications");

    const QString xdgDataDirs = QProcessEnvironment::systemEnvironment().value(
        QStringLiteral("XDG_DATA_DIRS"),
        QStringLiteral("/usr/local/share:/usr/share"));

    const QStringList dataDirs = xdgDataDirs.split(QLatin1Char(':'), Qt::SkipEmptyParts);
    for (const QString &dataDir : dataDirs)
        dirs << dataDir + QStringLiteral("/applications");

    dirs << QStringLiteral("/usr/local/share/applications");
    dirs << QStringLiteral("/usr/share/applications");

    dirs.removeDuplicates();
    return dirs;
}

QStringList AppRegistry::iconThemeDirs()
{
    QStringList dirs;

    const QString xdgDataHome = QProcessEnvironment::systemEnvironment().value(
        QStringLiteral("XDG_DATA_HOME"),
        QDir::homePath() + QStringLiteral("/.local/share"));

    dirs << xdgDataHome + QStringLiteral("/icons");
    dirs << QDir::homePath() + QStringLiteral("/.icons");

    const QString xdgDataDirs = QProcessEnvironment::systemEnvironment().value(
        QStringLiteral("XDG_DATA_DIRS"),
        QStringLiteral("/usr/local/share:/usr/share"));
    const QStringList dataDirs = xdgDataDirs.split(QLatin1Char(':'), Qt::SkipEmptyParts);
    for (const QString &dataDir : dataDirs)
        dirs << dataDir + QStringLiteral("/icons");

    dirs << QStringLiteral("/usr/local/share/icons");
    dirs << QStringLiteral("/usr/share/icons");
    dirs << QStringLiteral("/usr/share/pixmaps");

    dirs.removeDuplicates();
    return dirs;
}

bool AppRegistry::parseDesktopFile(const QString &path, Entry *entry, bool *broken)
{
    const QHash<QString, QString> values = readDesktopEntry(path);

    if (values.value(QStringLiteral("Type")) != QLatin1String("Application"))
        return false;

    if (isTruthy(values.value(QStringLiteral("NoDisplay")))
        || isTruthy(values.value(QStringLiteral("Hidden")))) {
        return false;
    }

    const QString name = values.value(QStringLiteral("Name"));
    const QString rawExec = values.value(QStringLiteral("Exec"));

    if (name.isEmpty() || rawExec.isEmpty()) {
        *broken = true;
        return false;
    }

    const QStringList tokens = QProcess::splitCommand(rawExec);
    if (tokens.isEmpty()) {
        *broken = true;
        return false;
    }

    // Field codes (%u, %U, %f, %F, %i, %c, %k) are removed here: they are instructions to
    // the launcher, not arguments. Everything else is preserved verbatim.
    QString program = tokens.first();
    QStringList arguments;
    for (int i = 0; i < tokens.size(); ++i) {
        const QString token = tokens.at(i);
        if (i > 0)
            arguments << token;
    }
    arguments.removeAll(QString());
    arguments.erase(std::remove_if(arguments.begin(), arguments.end(),
                                   [](const QString &token) {
                                       return token.startsWith(QLatin1Char('%'))
                                           && token.size() <= 2;
                                   }),
                    arguments.end());

    // TryExec is an explicit "only show me if this exists" hint.
    const QString tryExec = values.value(QStringLiteral("TryExec"));
    if (!tryExec.isEmpty() && QStandardPaths::findExecutable(tryExec).isEmpty()) {
        *broken = true;
        return false;
    }

    if (QStandardPaths::findExecutable(program).isEmpty() && !QFileInfo(program).isExecutable()) {
        // The entry points at a program that is not installed. Report it rather than
        // showing a launcher icon that cannot work.
        *broken = true;
        return false;
    }

    entry->id = QFileInfo(path).completeBaseName();
    entry->name = name;
    entry->exec = QStandardPaths::findExecutable(program).isEmpty() ? program
                                                                   : QStandardPaths::findExecutable(program);
    entry->arguments = arguments.join(QLatin1Char(' '));
    entry->iconName = values.value(QStringLiteral("Icon"));
    entry->iconPath = QString();
    entry->comment = values.value(QStringLiteral("Comment"));
    entry->categories = values.value(QStringLiteral("Categories"));
    entry->terminal = isTruthy(values.value(QStringLiteral("Terminal")));
    entry->desktopFile = path;
    return true;
}

QString AppRegistry::resolveIcon(const QString &iconName) const
{
    if (iconName.isEmpty())
        return QString();

    // Some entries reference an absolute file directly.
    if (iconName.startsWith(QLatin1Char('/')))
        return QFileInfo::exists(iconName) ? iconName : QString();

    const QStringList sizes = {
        QStringLiteral("scalable"),
        QStringLiteral("256x256"),
        QStringLiteral("128x128"),
        QStringLiteral("64x64"),
        QStringLiteral("48x48"),
        QStringLiteral("32x32")
    };
    const QStringList extensions = { QStringLiteral("png"), QStringLiteral("svg"),
                                     QStringLiteral("xpm") };

    const QStringList themes = { QStringLiteral("hicolor"), QStringLiteral("Adwaita"),
                                 QStringLiteral("gnome"), QStringLiteral("breeze") };
    const QStringList themeDirs = iconThemeDirs();

    for (const QString &themeDir : themeDirs) {
        for (const QString &theme : themes) {
            for (const QString &size : sizes) {
                for (const QString &extension : extensions) {
                    const QString candidate = QStringLiteral("%1/%2/%3/apps/%4.%5")
                                                  .arg(themeDir, theme, size, iconName,
                                                       extension);
                    if (QFileInfo::exists(candidate))
                        return candidate;
                }
            }
        }

        // Flat icon directories (for example /usr/share/pixmaps).
        for (const QString &extension : extensions) {
            const QString candidate = QStringLiteral("%1/%2.%3").arg(themeDir, iconName, extension);
            if (QFileInfo::exists(candidate))
                return candidate;
        }
    }

    return QString();
}

void AppRegistry::refresh()
{
    beginResetModel();
    m_entries.clear();
    m_byId.clear();
    m_broken = 0;

    const QStringList dirs = applicationDirs();
    QStringList seenFiles;

    for (const QString &dir : dirs) {
        QDir applicationDir(dir);
        if (!applicationDir.exists())
            continue;

        const QStringList files = applicationDir.entryList({ QStringLiteral("*.desktop") },
                                                          QDir::Files, QDir::Name);
        for (const QString &file : files) {
            const QString path = applicationDir.absoluteFilePath(file);

            if (seenFiles.contains(path))
                continue;
            seenFiles << path;

            Entry entry;
            bool broken = false;
            if (!parseDesktopFile(path, &entry, &broken)) {
                if (broken)
                    ++m_broken;
                continue;
            }

            insertEntry(entry);
        }
    }

    endResetModel();

    setStatus(QStringLiteral("%1 applications found (%2 unusable entries skipped)")
                  .arg(m_entries.size())
                  .arg(m_broken));
    emit countChanged();
}

void AppRegistry::insertEntry(const Entry &entry)
{
    // Earlier directories win, so a user override in ~/.local/share/applications hides the
    // system copy with the same desktop file id.
    if (m_byId.contains(entry.id))
        return;

    // Resolve the icon only for entries that survive, so scanning stays cheap.
    Entry resolved = entry;
    resolved.iconPath = resolveIcon(resolved.iconName);

    m_byId.insert(resolved.id, m_entries.size());
    m_entries.append(resolved);
}

int AppRegistry::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_entries.size();
}

QVariant AppRegistry::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());

    switch (role) {
    case IdRole:
        return entry.id;
    case NameRole:
        return entry.name;
    case ExecRole:
        return entry.exec;
    case IconNameRole:
        return entry.iconName;
    case IconPathRole:
        return entry.iconPath;
    case CommentRole:
        return entry.comment;
    case CategoriesRole:
        return entry.categories;
    case TerminalRole:
        return entry.terminal;
    case DesktopFileRole:
        return entry.desktopFile;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> AppRegistry::roleNames() const
{
    return {
        { IdRole, QByteArrayLiteral("desktopId") },
        { NameRole, QByteArrayLiteral("name") },
        { ExecRole, QByteArrayLiteral("exec") },
        { IconNameRole, QByteArrayLiteral("iconName") },
        { IconPathRole, QByteArrayLiteral("iconPath") },
        { CommentRole, QByteArrayLiteral("comment") },
        { CategoriesRole, QByteArrayLiteral("categories") },
        { TerminalRole, QByteArrayLiteral("terminal") },
        { DesktopFileRole, QByteArrayLiteral("desktopFile") }
    };
}

QVariantList AppRegistry::toVariantList() const
{
    QVariantList list;
    for (const Entry &entry : m_entries) {
        QVariantMap item;
        item.insert(QStringLiteral("desktopId"), entry.id);
        item.insert(QStringLiteral("name"), entry.name);
        item.insert(QStringLiteral("exec"), entry.exec);
        item.insert(QStringLiteral("iconPath"), entry.iconPath);
        item.insert(QStringLiteral("iconName"), entry.iconName);
        item.insert(QStringLiteral("comment"), entry.comment);
        list.append(item);
    }
    return list;
}

int AppRegistry::launchRow(int row)
{
    if (row < 0 || row >= m_entries.size()) {
        setLastError(QStringLiteral("No application at row %1").arg(row));
        emit launchFinished(QString(), NotFound);
        return NotFound;
    }

    return startDetached(m_entries.at(row).id, m_entries.at(row));
}

int AppRegistry::launchDesktopId(const QString &desktopId)
{
    const int row = m_byId.value(desktopId, -1);
    if (row < 0) {
        setLastError(QStringLiteral("No application with id '%1' is installed").arg(desktopId));
        emit launchFinished(desktopId, NotFound);
        return NotFound;
    }

    return startDetached(desktopId, m_entries.at(row));
}

int AppRegistry::startDetached(const QString &desktopId, const Entry &entry)
{
    const QStringList arguments = QProcess::splitCommand(entry.arguments);

    const bool started = QProcess::startDetached(entry.exec, arguments, QDir::homePath());
    if (!started) {
        setLastError(QStringLiteral("Failed to start %1 (%2)").arg(entry.name, entry.exec));
        emit launchFinished(desktopId, Failed);
        return Failed;
    }

    setLastError(QString());
    emit launchFinished(desktopId, Started);
    return Started;
}

int AppRegistry::openPath(const QString &path)
{
    const QString xdgOpen = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
    if (xdgOpen.isEmpty()) {
        setLastError(QStringLiteral("xdg-open is not installed, so files cannot be opened"));
        return NotFound;
    }

    if (!QProcess::startDetached(xdgOpen, QStringList { path })) {
        setLastError(QStringLiteral("Failed to open %1").arg(path));
        return Failed;
    }

    setLastError(QString());
    return Started;
}

void AppRegistry::setLastError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}

void AppRegistry::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}
