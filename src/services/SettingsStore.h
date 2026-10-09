#pragma once

#include <QObject>
#include <QVariantMap>
#include <QString>

/* Project Tahoe X86 settings persistence service.
 *
 * Owns all settings file I/O so QML never touches the filesystem directly.
 *
 * Contract (see src/services/Settings.qml for the matching model):
 *   location: $XDG_CONFIG_HOME/project-tahoe/shell/settings.json
 *             ($XDG_CONFIG_HOME defaults to $HOME/.config)
 *   format:   JSON object of preference keys
 *   failure:  a missing file means "defaults in use" and is NOT an error; an
 *             unreadable or invalid file is reported and is never overwritten.
 *   writes:   atomic (QSaveFile), so a crash mid-write cannot corrupt settings.
 *
 * Secrets are never stored here. Credentials belong in the Secret Service keyring.
 */
class SettingsStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString configPath READ configPath NOTIFY configPathChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool available READ available NOTIFY statusChanged)

public:
    explicit SettingsStore(QObject *parent = nullptr);

    QString configPath() const { return m_configPath; }
    QString status() const { return m_status; }
    bool available() const { return m_available; }

    // Returns the stored values. An empty map with status "Defaults in use (...)"
    // means: use defaults. Callers must not treat that as a hard failure.
    Q_INVOKABLE QVariantMap load();

    // Writes the given values atomically. Returns false and emits saveFailed on error.
    Q_INVOKABLE bool save(const QVariantMap &values);

signals:
    void configPathChanged();
    void statusChanged();
    void loadFailed(const QString &reason);
    void saveFailed(const QString &reason);

private:
    void setStatus(const QString &status);
    static QString resolveConfigDir();
    QString m_configPath;
    QString m_status;
    bool m_available = false;
};
