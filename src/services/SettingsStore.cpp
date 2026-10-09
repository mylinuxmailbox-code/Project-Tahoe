#include "SettingsStore.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSaveFile>

SettingsStore::SettingsStore(QObject *parent)
    : QObject(parent)
    , m_status(QStringLiteral("Uninitialized"))
{
    const QString dir = resolveConfigDir();
    if (dir.isEmpty()) {
        setStatus(QStringLiteral("Unavailable: neither XDG_CONFIG_HOME nor a usable HOME is set"));
        return;
    }

    QDir configDir(dir);
    if (!configDir.exists() && !configDir.mkpath(QStringLiteral("."))) {
        setStatus(QStringLiteral("Unavailable: cannot create ") + dir);
        return;
    }

    // Probe writability before declaring the store usable, so QML can trust `available`.
    QFile probe(configDir.filePath(QStringLiteral(".write-probe")));
    if (!probe.open(QIODevice::WriteOnly)) {
        setStatus(QStringLiteral("Unavailable: ") + dir + QStringLiteral(" is not writable"));
        return;
    }
    probe.close();
    probe.remove();

    m_configPath = configDir.filePath(QStringLiteral("settings.json"));
    m_available = true;
    setStatus(QStringLiteral("Ready"));
    emit configPathChanged();
}

QString SettingsStore::resolveConfigDir()
{
    const QByteArray xdg = qgetenv("XDG_CONFIG_HOME");
    QString base;
    if (!xdg.isEmpty()) {
        base = QString::fromLocal8Bit(xdg);
    } else {
        const QString home = QDir::homePath();
        if (home.isEmpty() || home == QDir::rootPath()) {
            return QString();
        }
        base = home + QStringLiteral("/.config");
    }
    return base + QStringLiteral("/project-tahoe/shell");
}

void SettingsStore::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }
    m_status = status;
    emit statusChanged();
}

QVariantMap SettingsStore::load()
{
    QVariantMap values;
    if (!m_available) {
        emit loadFailed(m_status);
        return values;
    }

    QFile file(m_configPath);
    if (!file.exists()) {
        // Not an error: first run with default preferences.
        setStatus(QStringLiteral("Defaults in use (no settings file yet)"));
        return values;
    }

    if (!file.open(QIODevice::ReadOnly)) {
        const QString reason = file.errorString();
        setStatus(QStringLiteral("Defaults in use (cannot read settings file: ") + reason + QLatin1Char(')'));
        emit loadFailed(reason);
        return values;
    }

    const QByteArray raw = file.readAll();
    file.close();

    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(raw, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        // Reported, never overwritten: the user's file is left exactly as found.
        const QString reason = parseError.error == QJsonParseError::NoError
                                   ? QStringLiteral("settings file is not a JSON object")
                                   : parseError.errorString();
        setStatus(QStringLiteral("Defaults in use (") + reason + QLatin1Char(')'));
        emit loadFailed(reason);
        return values;
    }

    setStatus(QStringLiteral("Loaded"));
    return document.object().toVariantMap();
}

bool SettingsStore::save(const QVariantMap &values)
{
    if (!m_available) {
        emit saveFailed(m_status);
        return false;
    }

    const QJsonDocument document(QJsonObject::fromVariantMap(values));
    const QByteArray payload = document.toJson(QJsonDocument::Indented);

    QSaveFile file(m_configPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const QString reason = file.errorString();
        setStatus(QStringLiteral("Save failed: ") + reason);
        emit saveFailed(reason);
        return false;
    }

    if (file.write(payload) != payload.size()) {
        const QString reason = file.errorString();
        file.cancelWriting();
        setStatus(QStringLiteral("Save failed: ") + reason);
        emit saveFailed(reason);
        return false;
    }

    if (!file.commit()) {
        const QString reason = file.errorString();
        setStatus(QStringLiteral("Save failed: ") + reason);
        emit saveFailed(reason);
        return false;
    }

    setStatus(QStringLiteral("Saved"));
    return true;
}
