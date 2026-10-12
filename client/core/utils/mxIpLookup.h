#pragma once
#include <QByteArray>
#include <QPair>
#include <QString>
#include <QHostAddress>
namespace mxvpn {
inline QPair<QString,QString> parseIpTrace(const QByteArray &body) {
    if (body.size() > 16384) return {};
    QString ip, country;
    for (const auto &line : body.split('\n')) {
        if (line.startsWith("ip=")) ip = QString::fromUtf8(line.mid(3)).trimmed();
        if (line.startsWith("loc=")) country = QString::fromUtf8(line.mid(4)).trimmed();
    }
    QHostAddress address;
    if (!address.setAddress(ip) || country.size() != 2
        || country.at(0) < QLatin1Char('A') || country.at(0) > QLatin1Char('Z')
        || country.at(1) < QLatin1Char('A') || country.at(1) > QLatin1Char('Z')) return {};
    return {address.toString(), country};
}
}
