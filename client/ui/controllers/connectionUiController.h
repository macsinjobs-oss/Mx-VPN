#ifndef CONNECTIONUICONTROLLER_H
#define CONNECTIONUICONTROLLER_H

#include <QObject>
#include <QElapsedTimer>
#include <QPointer>
#include <QTimer>
#include "core/utils/mxTrafficSnapshot.h"

class QNetworkAccessManager;
class QNetworkReply;

#include "core/controllers/connectionController.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"
#include "core/protocols/vpnProtocol.h"
#include "core/controllers/serversController.h"

class ConnectionUiController : public QObject
{
    Q_OBJECT

public:
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStateChanged)
    Q_PROPERTY(bool isConnectionInProgress READ isConnectionInProgress NOTIFY connectionStateChanged)
    Q_PROPERTY(QString connectionStateText READ connectionStateText NOTIFY connectionStateChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY connectionStateChanged)
    Q_PROPERTY(QString publicIp READ publicIp NOTIFY dashboardChanged)
    Q_PROPERTY(QString country READ country NOTIFY dashboardChanged)
    Q_PROPERTY(QString lookupStatus READ lookupStatus NOTIFY dashboardChanged)
    Q_PROPERTY(QString durationText READ durationText NOTIFY dashboardChanged)
    Q_PROPERTY(QString downloadSpeedText READ downloadSpeedText NOTIFY dashboardChanged)
    Q_PROPERTY(QString uploadSpeedText READ uploadSpeedText NOTIFY dashboardChanged)
    Q_PROPERTY(QString transferredText READ transferredText NOTIFY dashboardChanged)

    explicit ConnectionUiController(ConnectionController* connectionController,
                                    ServersController* serversController,
                                    QObject *parent = nullptr);

    ~ConnectionUiController() = default;

    bool isConnected() const;
    bool isConnectionInProgress() const;
    QString connectionStateText() const;
    QString statusText() const;
    QString publicIp() const { return m_publicIp; }
    QString country() const { return m_country; }
    QString lookupStatus() const { return m_lookupStatus; }
    QString durationText() const;
    QString downloadSpeedText() const;
    QString uploadSpeedText() const;
    QString transferredText() const;

public slots:
    void refreshPublicIp();
    void onTrafficSample(quint64 receivedBytes, quint64 sentBytes);
    void toggleConnection();

    void openConnection();
    void closeConnection();

    bool isRevokeBlockedDuringActiveConnection(const QString &serverId, int containerIndex, const QString &clientId) const;

    ErrorCode getLastConnectionError();
    void onConnectionStateChanged(Vpn::ConnectionState state);

    void onTranslationsUpdated();

signals:
    void dashboardChanged();
    void connectionStateChanged();

    void connectionErrorOccurred(ErrorCode errorCode);

    void connectButtonClicked();
    void preparingConfig();
    void prepareConfig();
    void unsupportedConnectDrawerRequested();
    void noInstalledContainers();

private:
    Vpn::ConnectionState getCurrentConnectionState();
    void notifyConnectionBlocked(ErrorCode errorCode);

    ConnectionController* m_connectionController;
    ServersController* m_serversController;

    bool m_isConnected = false;
    bool m_isConnectionInProgress = false;
    QString m_connectionStateText = tr("Connect");

    Vpn::ConnectionState m_state;
    mxvpn::TrafficSnapshot m_traffic;
    QElapsedTimer m_sampleClock;
    QElapsedTimer m_sessionClock;
    QTimer m_dashboardTimer;
    qint64 m_lastTrafficAt = -1;
    qint64 m_sessionMilliseconds = 0;
    QNetworkAccessManager *m_ipNetwork = nullptr;
    QPointer<QNetworkReply> m_ipReply;
    quint64 m_lookupGeneration = 0;
    int m_lookupRetriesLeft = 0;
    QString m_publicIp;
    QString m_country;
    QString m_lookupStatus;
};

#endif
