#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVector>

/* Project Tahoe X86 application registry.
 *
 * Scans the XDG application directories for .desktop entries and exposes the result as
 * a model, so the Dock, Spotlight, and the Finder's "Applications" location can list the
 * applications that actually exist on this machine instead of a hardcoded list.
 *
 * Sources, in precedence order (earlier entries win on id collision):
 *   $XDG_DATA_HOME/applications  (defaults to $HOME/.local/share/applications)
 *   each entry of $XDG_DATA_DIRS + /applications
 *   /usr/local/share/applications
 *   /usr/share/applications
 *
 * Honesty rules:
 *   - A .desktop entry is only exposed if its executable resolves on PATH (TryExec, or the
 *     Exec program). Broken entries are counted and reported through status(), not hidden.
 *   - Entries marked NoDisplay=true or Hidden=true are excluded (standard behaviour).
 *   - launch() reports exactly what happened; it never reports success for a failed start.
 */
class AppRegistry : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int brokenCount READ brokenCount NOTIFY countChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    // Read from QML as a property (AppRegistry.lastError) to explain a failed launch.
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ExecRole,
        IconNameRole,
        IconPathRole,
        CommentRole,
        CategoriesRole,
        TerminalRole,
        DesktopFileRole
    };
    Q_ENUM(Role)

    struct Entry {
        QString id;          // desktop file base name, e.g. "org.gnome.Terminal"
        QString name;        // localised display name
        QString exec;        // executable path resolved at scan time
        QString arguments;   // argument template with field codes removed
        QString iconName;    // icon name as written in the .desktop file
        QString iconPath;    // resolved absolute icon file path, or empty
        QString comment;
        QString categories;
        bool terminal = false;
        QString desktopFile;
    };

    explicit AppRegistry(QObject *parent = nullptr);

    int count() const { return m_entries.size(); }
    int brokenCount() const { return m_broken; }
    QString status() const { return m_status; }

    // QAbstractListModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Rescan the application directories.
    Q_INVOKABLE void refresh();

    // Launch the entry at row, or the first entry whose id matches desktopId.
    // Returns an AppRegistry::LaunchResult value.
    Q_INVOKABLE int launchRow(int row);
    Q_INVOKABLE int launchDesktopId(const QString &desktopId);

    // Open a file or URL with the desktop's default handler.
    Q_INVOKABLE int openPath(const QString &path);

    // Resolved entries for QML code that needs a plain list (Spotlight, menus).
    Q_INVOKABLE QVariantList toVariantList() const;

    // Icon file for an icon name, or empty when no theme icon exists.
    Q_INVOKABLE QString resolveIcon(const QString &iconName) const;

    // Human-readable explanation of the most recent failure, empty when the last call worked.
    QString lastError() const { return m_lastError; }

    enum LaunchResult {
        Started = 0,
        NotFound = 1,
        Failed = 2
    };
    Q_ENUM(LaunchResult)

signals:
    void countChanged();
    void statusChanged();
    void lastErrorChanged();
    void launchFinished(const QString &desktopId, int result);

private:
    static QStringList applicationDirs();
    static QStringList iconThemeDirs();
    static bool parseDesktopFile(const QString &path, Entry *entry, bool *broken);
    void insertEntry(const Entry &entry);
    int startDetached(const QString &desktopId, const Entry &entry);
    void setStatus(const QString &status);
    void setLastError(const QString &message);

    QVector<Entry> m_entries;
    QHash<QString, int> m_byId;
    int m_broken = 0;
    QString m_status;
    QString m_lastError;
};
