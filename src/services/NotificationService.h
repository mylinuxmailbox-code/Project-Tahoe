#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QString>
#include <QVariant>
#include <QVector>

#ifdef TAHOE_HAS_DBUS
class NotificationServer;
#endif

/* Project Tahoe X86 notification service.
 *
 * Holds the notification list behind the Notification Centre and acts as the session's
 * org.freedesktop.Notifications server when that bus name is free. Applications that raise
 * a notification therefore appear in this shell for real.
 *
 * Honesty rules:
 *   - dbusStatus() reports whether this process actually owns the notification bus name.
 *     If another daemon already owns it, notifications from other applications will not
 *     appear here and the shell says so instead of showing an empty, misleading list.
 *   - Dismissing and clearing are real model operations; nothing is simulated.
 *   - Notification text is never executed, parsed as markup, or used as a path.
 */
class NotificationService : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY countChanged)
    Q_PROPERTY(QString dbusStatus READ dbusStatus NOTIFY dbusStatusChanged)

public:
    enum Role {
        IdRole = Qt::UserRole + 1,
        AppNameRole,
        SummaryRole,
        BodyRole,
        UrgencyRole,
        TimestampRole,
        AgeRole,
        ReadRole,
        HasActionsRole
    };
    Q_ENUM(Role)

    struct Item {
        uint id = 0;
        QString appName;
        QString summary;
        QString body;
        int urgency = 1; // 0 low, 1 normal, 2 critical
        QDateTime received;
        bool read = false;
        QStringList actions;
    };

    explicit NotificationService(QObject *parent = nullptr);
    ~NotificationService() override;

    int count() const { return m_items.size(); }
    int unreadCount() const;
    QString dbusStatus() const { return m_dbusStatus; }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Raise a notification from inside the shell. Returns the notification id.
    Q_INVOKABLE uint notify(const QString &appName, const QString &summary,
                            const QString &body, int urgency = 1);

    Q_INVOKABLE void dismiss(uint id);
    Q_INVOKABLE void dismissAll();
    Q_INVOKABLE void markAllRead();

    // The most recent unread notification summary, for the menu bar indicator.
    Q_INVOKABLE QString latestSummary() const;

    // Called by the D-Bus adaptor.
    uint raiseFromApplication(const QString &appName, uint replacesId, const QString &summary,
                              const QString &body, const QStringList &actions, int urgency);
    void closeById(uint id, uint reason);

signals:
    void countChanged();
    void dbusStatusChanged();
    void closed(uint id, uint reason);
    void actionInvoked(uint id, const QString &actionKey);

private:
    int indexOfId(uint id) const;
    void setDbusStatus(const QString &status);
    void setupDbus();

    QVector<Item> m_items;
    uint m_nextId = 1;
    QString m_dbusStatus;
#ifdef TAHOE_HAS_DBUS
    NotificationServer *m_server = nullptr;
#endif
};
