#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

#ifdef TAHOE_HAS_DBUS
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusObjectPath>
#endif

/* Project Tahoe X86 notification protocol bridge.
 *
 * Implements the org.freedesktop.Notifications interface on the session bus so that any
 * application on the system can raise notifications in this shell. Without this, the
 * notification centre would only ever show messages the shell sent to itself.
 *
 * The class is only compiled when Qt6::DBus is available (TAHOE_HAS_DBUS). When it is not,
 * NotificationService reports that plainly instead of pretending notifications work.
 */
#ifdef TAHOE_HAS_DBUS

class NotificationService;

class NotificationServer : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
    Q_CLASSINFO("D-Bus Introspection", ""
"  <interface name=\"org.freedesktop.Notifications\">\n"
"    <method name=\"GetCapabilities\">\n"
"      <arg direction=\"out\" type=\"as\" name=\"capabilities\"/>\n"
"    </method>\n"
"    <method name=\"Notify\">\n"
"      <arg direction=\"in\" type=\"s\" name=\"app_name\"/>\n"
"      <arg direction=\"in\" type=\"u\" name=\"replaces_id\"/>\n"
"      <arg direction=\"in\" type=\"s\" name=\"app_icon\"/>\n"
"      <arg direction=\"in\" type=\"s\" name=\"summary\"/>\n"
"      <arg direction=\"in\" type=\"s\" name=\"body\"/>\n"
"      <arg direction=\"in\" type=\"as\" name=\"actions\"/>\n"
"      <arg direction=\"in\" type=\"a{sv}\" name=\"hints\"/>\n"
"      <arg direction=\"in\" type=\"i\" name=\"expire_timeout\"/>\n"
"      <arg direction=\"out\" type=\"u\" name=\"id\"/>\n"
"    </method>\n"
"    <method name=\"CloseNotification\">\n"
"      <arg direction=\"in\" type=\"u\" name=\"id\"/>\n"
"    </method>\n"
"    <method name=\"GetServerInformation\">\n"
"      <arg direction=\"out\" type=\"s\" name=\"name\"/>\n"
"      <arg direction=\"out\" type=\"s\" name=\"vendor\"/>\n"
"      <arg direction=\"out\" type=\"s\" name=\"version\"/>\n"
"      <arg direction=\"out\" type=\"s\" name=\"spec_version\"/>\n"
"    </method>\n"
"    <signal name=\"NotificationClosed\">\n"
"      <arg type=\"u\" name=\"id\"/>\n"
"      <arg type=\"u\" name=\"reason\"/>\n"
"    </signal>\n"
"    <signal name=\"ActionInvoked\">\n"
"      <arg type=\"u\" name=\"id\"/>\n"
"      <arg type=\"s\" name=\"action_key\"/>\n"
"    </signal>\n"
"  </interface>")

public:
    explicit NotificationServer(NotificationService *service);

public Q_SLOTS: // D-Bus methods
    QStringList GetCapabilities();
    uint Notify(const QString &appName, uint replacesId, const QString &appIcon,
                const QString &summary, const QString &body, const QStringList &actions,
                const QVariantMap &hints, int expireTimeout);
    void CloseNotification(uint id);
    void GetServerInformation(QString &name, QString &vendor, QString &version,
                              QString &specVersion);

Q_SIGNALS: // D-Bus signals
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &actionKey);

private:
    NotificationService *m_service = nullptr;
};

#endif // TAHOE_HAS_DBUS
