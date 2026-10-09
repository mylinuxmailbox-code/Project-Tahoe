#include "NotificationServer.h"

#include "NotificationService.h"

#ifdef TAHOE_HAS_DBUS

#ifndef TAHOE_VERSION
#define TAHOE_VERSION "0.1.0"
#endif

NotificationServer::NotificationServer(NotificationService *service)
    : QDBusAbstractAdaptor(service)
    , m_service(service)
{
    // The adaptor must not relay signals on behalf of the object automatically: the shell
    // emits NotificationClosed only when a notification is genuinely gone.
    setAutoRelaySignals(false);
}

QStringList NotificationServer::GetCapabilities()
{
    // Only capability we can honestly back with behaviour: we keep notifications after the
    // timeout (persistence) and we render multi-line body text. We deliberately do NOT
    // advertise "actions" or "body-markup" because there is no UI that invokes actions and
    // body text is rendered as plain text.
    return { QStringLiteral("body"), QStringLiteral("persistence") };
}

uint NotificationServer::Notify(const QString &appName, uint replacesId, const QString &appIcon,
                                const QString &summary, const QString &body,
                                const QStringList &actions, const QVariantMap &hints,
                                int expireTimeout)
{
    Q_UNUSED(appIcon)

    int urgency = 1;
    const QVariant urgencyHint = hints.value(QStringLiteral("urgency"));
    if (urgencyHint.isValid())
        urgency = urgencyHint.toInt();

    Q_UNUSED(expireTimeout)

    if (!m_service)
        return 0;

    return m_service->raiseFromApplication(appName, replacesId, summary, body, actions, urgency);
}

void NotificationServer::CloseNotification(uint id)
{
    if (!m_service)
        return;

    // Reason 3 is closeRequested in the specification: another application asked for it.
    m_service->closeById(id, 3);
}

void NotificationServer::GetServerInformation(QString &name, QString &vendor, QString &version,
                                             QString &specVersion)
{
    name = QStringLiteral("Tahoe Shell");
    vendor = QStringLiteral("Project Tahoe");
    version = QStringLiteral(TAHOE_VERSION);
    specVersion = QStringLiteral("1.2");
}

#endif // TAHOE_HAS_DBUS
