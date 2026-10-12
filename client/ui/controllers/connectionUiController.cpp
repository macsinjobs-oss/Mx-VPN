#include "connectionUiController.h"

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS) || defined(MACOS_NE)
    #include <QGuiApplication>
#else
    #include <QApplication>
#endif

#include "amneziaApplication.h"
#include "core/controllers/serversController.h"
#include "core/models/containerConfig.h"
#include "core/utils/containerEnum.h"
#include "core/utils/mxIpLookup.h"
#include <QHostAddress>
#include <QJsonDocument>
#include <QLocale>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>

ConnectionUiController::ConnectionUiController(ConnectionController* connectionController,
                                                ServersController* serversController,
                                                QObject *parent)
    : QObject(parent),
      m_connectionController(connectionController),
      m_serversController(serversController)
{
    connect(m_connectionController, &ConnectionController::connectionStateChanged, this, &ConnectionUiController::onConnectionStateChanged);

    connect(this, &ConnectionUiController::connectButtonClicked, this, &ConnectionUiController::toggleConnection, Qt::QueuedConnection);

    m_state = Vpn::ConnectionState::Disconnected;
#ifdef MX_VPN_PERSONAL_BUILD
    m_sampleClock.start();
    m_ipNetwork = new QNetworkAccessManager(this);
    connect(m_connectionController, &ConnectionController::bytesChanged,
            this, &ConnectionUiController::onTrafficSample);
    connect(&m_dashboardTimer, &QTimer::timeout, this, &ConnectionUiController::dashboardChanged);
    m_dashboardTimer.start(1000);
    QTimer::singleShot(0, this, &ConnectionUiController::refreshPublicIp);
#endif
}

void ConnectionUiController::openConnection()
{
    const QString serverId = m_serversController->getDefaultServerId();
    if (serverId.isEmpty()) {
        m_connectionController->setConnectionState(Vpn::ConnectionState::Disconnected);
        return;
    }

    ErrorCode errorCode = m_connectionController->openConnection(serverId);

    if (errorCode != ErrorCode::NoError) {
        notifyConnectionBlocked(errorCode);
        return;
    }
}

void ConnectionUiController::closeConnection()
{
    m_connectionController->closeConnection();
}

ErrorCode ConnectionUiController::getLastConnectionError()
{
    return m_connectionController->lastConnectionError();
}

void ConnectionUiController::onConnectionStateChanged(Vpn::ConnectionState state)
{
    const auto previousState = m_state;
    m_state = state;

    m_isConnected = false;
    m_connectionStateText = tr("Connecting...");
    switch (state) {
    case Vpn::ConnectionState::Connected: {
        amnApp->networkManager()->clearConnectionCache();

        m_isConnectionInProgress = false;
        m_isConnected = true;
        m_connectionStateText = tr("Connected");
        break;
    }
    case Vpn::ConnectionState::Connecting: {
        m_isConnectionInProgress = true;
        break;
    }
    case Vpn::ConnectionState::Reconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Reconnecting...");
        break;
    }
    case Vpn::ConnectionState::Disconnected: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        break;
    }
    case Vpn::ConnectionState::Disconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Disconnecting...");
        break;
    }
    case Vpn::ConnectionState::Preparing: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Preparing...");
        break;
    }
    case Vpn::ConnectionState::Error: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    case Vpn::ConnectionState::Unknown: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    }
#ifdef MX_VPN_PERSONAL_BUILD
    if (state != previousState) {
        ++m_lookupGeneration;
        if (m_ipReply) { m_ipReply->abort(); m_ipReply.clear(); }
        m_lookupRetriesLeft = 1;
        m_publicIp.clear();
        m_country.clear();
        if (state == Vpn::ConnectionState::Connected) {
            m_traffic = {};
            m_lastTrafficAt = -1;
            m_sessionMilliseconds = 0;
            m_sessionClock.start();
            QTimer::singleShot(400, this, &ConnectionUiController::refreshPublicIp);
        } else {
            if (m_sessionClock.isValid()) {
                m_sessionMilliseconds = m_sessionClock.elapsed();
                m_sessionClock.invalidate();
            }
            m_lookupStatus.clear();
            if (state == Vpn::ConnectionState::Disconnected || state == Vpn::ConnectionState::Error) {
                QTimer::singleShot(400, this, &ConnectionUiController::refreshPublicIp);
            }
        }
        emit dashboardChanged();
    }
#endif
    emit connectionStateChanged();
}

namespace {
QString mxFormatBytes(double bytes) {
    const char *units[] = {"B", "KiB", "MiB", "GiB", "TiB"};
    int unit = 0;
    while (bytes >= 1024 && unit < 4) { bytes /= 1024; ++unit; }
    return QString::number(bytes, 'f', unit ? 1 : 0) + " " + units[unit];
}
}

QString ConnectionUiController::statusText() const {
    switch (m_state) {
    case Vpn::ConnectionState::Connected: return tr("Connected");
    case Vpn::ConnectionState::Reconnecting: return tr("Reconnecting");
    case Vpn::ConnectionState::Disconnected: return tr("Disconnected");
    case Vpn::ConnectionState::Disconnecting: return tr("Disconnecting");
    case Vpn::ConnectionState::Error:
    case Vpn::ConnectionState::Unknown: return tr("Failed");
    default: return tr("Connecting");
    }
}

QString ConnectionUiController::durationText() const {
    const auto seconds = (m_sessionClock.isValid() ? m_sessionClock.elapsed() : m_sessionMilliseconds) / 1000;
    return QString("%1:%2:%3").arg(seconds / 3600, 2, 10, QLatin1Char('0'))
        .arg(seconds / 60 % 60, 2, 10, QLatin1Char('0')).arg(seconds % 60, 2, 10, QLatin1Char('0'));
}

QString ConnectionUiController::downloadSpeedText() const {
    const bool fresh = m_isConnected && m_lastTrafficAt >= 0 && m_sampleClock.elapsed() - m_lastTrafficAt <= 3000;
    return mxFormatBytes(fresh ? m_traffic.downloadPerSecond : 0) + "/s";
}
QString ConnectionUiController::uploadSpeedText() const {
    const bool fresh = m_isConnected && m_lastTrafficAt >= 0 && m_sampleClock.elapsed() - m_lastTrafficAt <= 3000;
    return mxFormatBytes(fresh ? m_traffic.uploadPerSecond : 0) + "/s";
}
QString ConnectionUiController::transferredText() const {
    return mxFormatBytes(double(m_traffic.receivedBytes) + double(m_traffic.sentBytes));
}
void ConnectionUiController::onTrafficSample(quint64 receivedBytes, quint64 sentBytes) {
    if (!m_isConnected) return;
    m_lastTrafficAt = m_sampleClock.elapsed();
    m_traffic.sample(receivedBytes, sentBytes, m_lastTrafficAt);
    emit dashboardChanged();
}

void ConnectionUiController::refreshPublicIp() {
    if (!m_ipNetwork || m_isConnectionInProgress) return;
    const auto generation = ++m_lookupGeneration;
    if (m_ipReply) { m_ipReply->abort(); m_ipReply.clear(); }
    // Pooled connections may still be bound to the route used before a tunnel change.
    m_ipNetwork->clearConnectionCache();
    m_lookupStatus = tr("Checking IP…");
    emit dashboardChanged();
    QNetworkRequest request(QUrl("https://www.cloudflare.com/cdn-cgi/trace"));
    request.setTransferTimeout(30000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::SameOriginRedirectPolicy);
    auto *reply = m_ipNetwork->get(request);
    m_ipReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation]() {
        reply->deleteLater();
        if (generation != m_lookupGeneration) return;
        m_ipReply.clear();
        const auto body = reply->readAll();
        const auto result = mxvpn::parseIpTrace(body);
        const auto ip = result.first;
        const auto country = result.second;
        QHostAddress address;
        if (reply->error() != QNetworkReply::NoError || body.size() > 16384
            || !address.setAddress(ip) || country.size() != 2) {
            m_publicIp.clear(); m_country.clear();
            if (m_lookupRetriesLeft > 0) {
                // Routes and DNS can settle a few seconds after a state change.
                --m_lookupRetriesLeft;
                QTimer::singleShot(3000, this, [this, generation]() {
                    if (generation == m_lookupGeneration) refreshPublicIp();
                });
                return;
            }
            m_lookupStatus = tr("IP lookup unavailable. Retry when online.");
        } else {
            m_publicIp = address.toString();
            m_country = QLocale::territoryToString(QLocale::codeToTerritory(country));
            m_lookupStatus.clear();
        }
        emit dashboardChanged();
    });
}

void ConnectionUiController::onTranslationsUpdated()
{
    onConnectionStateChanged(getCurrentConnectionState());
}

Vpn::ConnectionState ConnectionUiController::getCurrentConnectionState()
{
    return m_state;
}

QString ConnectionUiController::connectionStateText() const
{
    return m_connectionStateText;
}

void ConnectionUiController::toggleConnection()
{
    if (m_state == Vpn::ConnectionState::Preparing) {
        emit preparingConfig();
        return;
    }

    if (isConnectionInProgress()) {
        closeConnection();
    } else if (isConnected()) {
        closeConnection();
    } else {
        const QString serverId = m_serversController->getDefaultServerId();
        if (serverId.isEmpty()) {
            return;
        }

        const ErrorCode errorCode = m_connectionController->isConnectionSupported(serverId);
        if (errorCode != ErrorCode::NoError) {
            notifyConnectionBlocked(errorCode);
            return;
        }

        emit prepareConfig();
    }
}

void ConnectionUiController::notifyConnectionBlocked(ErrorCode errorCode)
{
    if (errorCode == ErrorCode::LegacyApiV1NotSupportedError) {
        emit unsupportedConnectDrawerRequested();
        return;
    }

    if (errorCode == ErrorCode::NoInstalledContainersError) {
        emit noInstalledContainers();
        return;
    }

    emit connectionErrorOccurred(errorCode);
}

bool ConnectionUiController::isConnectionInProgress() const
{
    return m_isConnectionInProgress;
}

bool ConnectionUiController::isConnected() const
{
    return m_isConnected;
}

bool ConnectionUiController::isRevokeBlockedDuringActiveConnection(const QString &serverId, int containerIndex,
                                                                   const QString &clientId) const
{
    if (clientId.isEmpty() || (!isConnected() && !isConnectionInProgress())) {
        return false;
    }

    if (m_serversController->getDefaultServerId() != serverId) {
        return false;
    }

    if (static_cast<int>(m_serversController->getDefaultContainer(serverId)) != containerIndex) {
        return false;
    }

    const auto adminConfig = m_serversController->selfHostedAdminConfig(serverId);
    if (!adminConfig.has_value()) {
        return false;
    }

    const QString connectionClientId =
            adminConfig->containerConfig(static_cast<DockerContainer>(containerIndex)).protocolConfig.clientId();
    if (connectionClientId.isEmpty()) {
        return false;
    }

    return connectionClientId == clientId || connectionClientId.contains(clientId);
}
