// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QByteArray>
#include <QHostAddress>
#include <QMap>
#include <QRegularExpression>
#include <QSet>
#include <QStringList>

namespace mxvpn {
// Validate the personal client's supported subset before upstream conversion.
// Never return configuration values in diagnostics.
struct WireGuardImport {
    QMap<QString, QString> fields;
    QString error;
    bool valid() const { return error.isEmpty(); }
};

inline QStringList commaList(const QString &value)
{
    QStringList result;
    for (const auto &part : value.split(',')) {
        result.append(part.trimmed());
    }
    return result;
}

inline bool validKey(const QString &value)
{
    static const QRegularExpression format(QStringLiteral("^[A-Za-z0-9+/]{43}=$"));
    if (!format.match(value).hasMatch()) return false;
    const auto decoded = QByteArray::fromBase64(value.toLatin1());
    return decoded.size() == 32 && decoded != QByteArray(32, '\0')
        && decoded.toBase64() == value.toLatin1();
}

inline bool validCidr(const QString &value)
{
    const auto parts = value.split('/');
    if (parts.size() != 2) return false;
    QHostAddress address(parts[0]);
    bool ok = false;
    const int prefix = parts[1].toInt(&ok);
    const int maximum = address.protocol() == QAbstractSocket::IPv4Protocol ? 32 : 128;
    return !address.isNull() && ok && prefix >= 0 && prefix <= maximum;
}

inline WireGuardImport validateWireGuardImport(const QString &text)
{
    WireGuardImport result;
    const auto reject = [&result](const char *message) {
        result.fields.clear();
        result.error = QString::fromLatin1(message);
        return result;
    };
    if (text.size() > 65536 || text.contains(QChar('\0'))) {
        return reject("Configuration is oversized or contains invalid characters.");
    }
    const QSet<QString> interfaceFields { "PrivateKey", "Address", "DNS", "MTU" };
    const QSet<QString> peerFields { "PublicKey", "PresharedKey", "AllowedIPs", "Endpoint", "PersistentKeepalive" };
    QString section;
    bool seenInterface = false;
    bool seenPeer = false;
    for (QString line : text.split('\n')) {
        line = line.section('#', 0, 0).trimmed();
        if (line.isEmpty()) continue;
        if (line == "[Interface]") {
            if (seenInterface || seenPeer) return reject("Expected one Interface followed by one Peer.");
            seenInterface = true;
            section = "Interface";
            continue;
        }
        if (line == "[Peer]") {
            if (!seenInterface || seenPeer) return reject("Only one Peer per configuration is currently supported.");
            seenPeer = true;
            section = "Peer";
            continue;
        }
        const auto separator = line.indexOf('=');
        if (section.isEmpty() || separator <= 0) return reject("Invalid WireGuard configuration syntax.");
        const auto key = line.left(separator).trimmed();
        const auto value = line.mid(separator + 1).trimmed();
        const auto &allowed = section == "Interface" ? interfaceFields : peerFields;
        if (!allowed.contains(key)) return reject("Unsupported field or executable hook in configuration.");
        if (result.fields.contains(key) || value.isEmpty()) return reject("Duplicate or empty configuration field.");
        result.fields.insert(key, value);
    }
    if (!seenInterface || !seenPeer) return reject("Interface and Peer sections are required.");
    for (const auto &key : { "PrivateKey", "PublicKey" }) {
        if (!validKey(result.fields.value(key))) return reject("Invalid or missing WireGuard key.");
    }
    if (result.fields.contains("PresharedKey") && !validKey(result.fields.value("PresharedKey"))) {
        return reject("Invalid preshared key.");
    }
    for (const auto &key : { "Address", "AllowedIPs" }) {
        for (const auto &value : commaList(result.fields.value(key))) {
            if (!validCidr(value)) return reject("Invalid or missing IP address range.");
        }
    }
    const auto routes = commaList(result.fields.value("AllowedIPs"));
    if (!routes.contains("0.0.0.0/0") || !routes.contains("::/0")) {
        return reject("Personal VPN requires full IPv4 and IPv6 routes.");
    }
    const auto dns = commaList(result.fields.value("DNS"));
    if (dns.isEmpty() || dns.size() > 2) return reject("One or two tunnel DNS addresses are required.");
    for (const auto &value : dns) {
        if (QHostAddress(value).isNull()) return reject("Invalid or missing tunnel DNS address.");
    }
    static const QRegularExpression endpointFormat(QStringLiteral("^(?:\\[([^\\]]+)\\]|([^:\\s/]+)):(\\d{1,5})$"));
    const auto endpoint = endpointFormat.match(result.fields.value("Endpoint"));
    if (!endpoint.hasMatch()) return reject("Endpoint must include a host and port.");
    const auto host = endpoint.captured(1).isEmpty() ? endpoint.captured(2) : endpoint.captured(1);
    static const QRegularExpression hostnameFormat(QStringLiteral("^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$"));
    if (!endpoint.captured(1).isEmpty()) {
        if (QHostAddress(host).protocol() != QAbstractSocket::IPv6Protocol) return reject("Invalid IPv6 endpoint.");
    } else if (QHostAddress(host).isNull() && !hostnameFormat.match(host).hasMatch()) {
        return reject("Invalid endpoint host.");
    }
    const int port = endpoint.captured(3).toInt();
    if (port < 1 || port > 65535) return reject("Invalid endpoint port.");
    for (const auto &key : { "MTU", "PersistentKeepalive" }) {
        if (!result.fields.contains(key)) continue;
        bool ok = false;
        const int number = result.fields.value(key).toInt(&ok);
        const int minimum = QString::fromLatin1(key) == "MTU" ? 1280 : 0;
        if (!ok || number < minimum || number > 65535) return reject("Invalid MTU or keepalive value.");
    }
    return result;
}
}
