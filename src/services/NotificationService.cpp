#include "NotificationService.h"

#include "NotificationServer.h"

#include <QDebug>

namespace {

// The centre keeps a bounded history so a chatty application cannot grow the list without
// limit. The oldest entries are dropped first.
constexpr int kMaximumRetained = 200;

} // namespace

NotificationService::NotificationService(QObject *parent)
    : QAbstractListModel(parent)
{
    setupDbus();
}

NotificationService::~NotificationService()
{
#ifdef TAHOE_HAS_DBUS
    if (m_server) {
        QDBusConnection bus = QDBusConnection::sessionBus();
        bus.unregisterObject(QStringLiteral("/org/freedesktop/Notifications"));
        bus.unregisterService(QStringLiteral("org.freedesktop.Notifications"));
        delete m_server;
        m_server = nullptr;
    }
#endif
}

void NotificationService::setupDbus()
{
#ifdef TAHOE_HAS_DBUS
    QDBusConnection bus = QDBusConnection::sessionBus();

    if (!bus.isConnected()) {
        setDbusStatus(QStringLiteral("No session bus is available, so notifications from "
                                     "other applications cannot be received"));
        return;
    }

    // Another daemon (dunst, mako, gnome-shell) may already own the notification name. In
    // that case the honest outcome is to say so: their notifications will not reach us.
    if (!bus.registerService(QStringLiteral("org.freedesktop.Notifications"))) {
        setDbusStatus(QStringLiteral("Another notification service owns "
                                     "org.freedesktop.Notifications, so notifications from "
                                     "other applications are shown by it, not here"));
        return;
    }

    m_server = new NotificationServer(this);

    if (!bus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), this,
                            QDBusConnection::ExportAdaptors)) {
        setDbusStatus(QStringLiteral("Could not export the notification object on the session "
                                     "bus"));
        bus.unregisterService(QStringLiteral("org.freedesktop.Notifications"));
        delete m_server;
        m_server = nullptr;
        return;
    }

    setDbusStatus(QStringLiteral("This shell is the session notification server"));
#else
    setDbusStatus(QStringLiteral("Built without Qt6::DBus, so notifications from other "
                                 "applications cannot be received; shell notifications work"));
#endif
}

int NotificationService::unreadCount() const
{
    int unread = 0;
    for (const Item &item : m_items) {
        if (!item.read)
            ++unread;
    }
    return unread;
}

uint NotificationService::notify(const QString &appName, const QString &summary,
                                const QString &body, int urgency)
{
    return raiseFromApplication(appName, 0, summary, body, QStringList(), urgency);
}

uint NotificationService::raiseFromApplication(const QString &appName, uint replacesId,
                                              const QString &summary, const QString &body,
                                              const QStringList &actions, int urgency)
{
    const QString resolvedApp = appName.trimmed().isEmpty()
        ? QStringLiteral("Unknown application")
        : appName.trimmed();

    const int clampedUrgency = qBound(0, urgency, 2);

    // A replaces_id means "replace my previous notification in place", which is what
    // applications use to update a progress notification rather than stacking copies.
    if (replacesId != 0) {
        const int existing = indexOfId(replacesId);
        if (existing >= 0) {
            Item &item = m_items[existing];
            item.appName = resolvedApp;
            item.summary = summary;
            item.body = body;
            item.urgency = clampedUrgency;
            item.received = QDateTime::currentDateTime();
            item.read = false;
            item.actions = actions;

            const QModelIndex changed = index(existing);
            emit dataChanged(changed, changed);
            emit countChanged();
            return replacesId;
        }
    }

    const int insertAt = 0; // newest first
    beginInsertRows(QModelIndex(), insertAt, insertAt);

    Item item;
    item.id = m_nextId++;
    item.appName = resolvedApp;
    item.summary = summary;
    item.body = body;
    item.urgency = clampedUrgency;
    item.received = QDateTime::currentDateTime();
    item.read = false;
    item.actions = actions;

    m_items.insert(insertAt, item);

    if (m_items.size() > kMaximumRetained) {
        // Trim silently: this is retention policy, not a user-visible event.
        m_items.resize(kMaximumRetained);
    }

    endInsertRows();
    emit countChanged();

    return item.id;
}

int NotificationService::indexOfId(uint id) const
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).id == id)
            return i;
    }
    return -1;
}

void NotificationService::dismiss(uint id)
{
    const int row = indexOfId(id);
    if (row < 0)
        return;

    beginRemoveRows(QModelIndex(), row, row);
    m_items.removeAt(row);
    endRemoveRows();

    emit countChanged();
    emit closed(id, 2 /* dismissed by the user */);
}

void NotificationService::dismissAll()
{
    if (m_items.isEmpty())
        return;

    beginResetModel();
    const QVector<Item> removed = m_items;
    m_items.clear();
    endResetModel();

    emit countChanged();

    for (const Item &item : removed)
        emit closed(item.id, 2);
}

void NotificationService::markAllRead()
{
    if (m_items.isEmpty())
        return;

    for (Item &item : m_items)
        item.read = true;

    emit dataChanged(index(0), index(m_items.size() - 1), { ReadRole });
    emit countChanged();
}

void NotificationService::closeById(uint id, uint reason)
{
    const int row = indexOfId(id);
    if (row < 0)
        return;

    beginRemoveRows(QModelIndex(), row, row);
    m_items.removeAt(row);
    endRemoveRows();

    emit countChanged();
    emit closed(id, reason);
}

QString NotificationService::latestSummary() const
{
    for (const Item &item : m_items) {
        if (!item.read)
            return item.summary;
    }
    return QString();
}

int NotificationService::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant NotificationService::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();

    const Item &item = m_items.at(index.row());

    switch (role) {
    case IdRole:
        return item.id;
    case AppNameRole:
        return item.appName;
    case SummaryRole:
        return item.summary;
    case BodyRole:
        return item.body;
    case UrgencyRole:
        return item.urgency;
    case TimestampRole:
        return item.received;
    case AgeRole:
        return item.received.secsTo(QDateTime::currentDateTime());
    case ReadRole:
        return item.read;
    case HasActionsRole:
        return !item.actions.isEmpty();
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> NotificationService::roleNames() const
{
    return {
        { IdRole, QByteArrayLiteral("notificationId") },
        { AppNameRole, QByteArrayLiteral("appName") },
        { SummaryRole, QByteArrayLiteral("summary") },
        { BodyRole, QByteArrayLiteral("body") },
        { UrgencyRole, QByteArrayLiteral("urgency") },
        { TimestampRole, QByteArrayLiteral("received") },
        { AgeRole, QByteArrayLiteral("ageSeconds") },
        { ReadRole, QByteArrayLiteral("isRead") },
        { HasActionsRole, QByteArrayLiteral("hasActions") }
    };
}

void NotificationService::setDbusStatus(const QString &status)
{
    if (m_dbusStatus == status)
        return;
    m_dbusStatus = status;
    emit dbusStatusChanged();
}
