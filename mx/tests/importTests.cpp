// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include "core/utils/mxWireGuardValidation.h"

class ImportTests : public QObject {
    Q_OBJECT
    QString fixture() const {
        // Synthetic bytes only. Never use these fixtures for a real tunnel.
        return "# Synthetic Proton-shaped fixture\n[Interface]\nPrivateKey = "
            + QString::fromLatin1(QByteArray(32, 'a').toBase64())
            + "\nAddress = 10.2.0.2/32\nDNS = 10.2.0.1\n[Peer]\nPublicKey = "
            + QString::fromLatin1(QByteArray(32, 'b').toBase64())
            + "\nAllowedIPs = 0.0.0.0/0, ::/0\nEndpoint = 192.0.2.1:51820\nPersistentKeepalive = 25\n";
    }
private slots:
    void protonShape() {
        auto result = mxvpn::validateWireGuardImport(fixture());
        QVERIFY2(result.valid(), qPrintable(result.error));
        QCOMPARE(result.fields.value("DNS"), "10.2.0.1");
        QCOMPARE(mxvpn::commaList(result.fields.value("AllowedIPs")), QStringList({"0.0.0.0/0", "::/0"}));
    }
    void commentsAndWindowsNewlines() {
        auto text = fixture().replace("DNS = 10.2.0.1", "DNS=10.2.0.1 # tunnel resolver");
        QVERIFY(mxvpn::validateWireGuardImport(text.replace("\n", "\r\n")).valid());
    }
    void validOptionalFields() {
        auto text = fixture().replace("DNS = 10.2.0.1", "DNS = 10.2.0.1, 10.2.0.1\nMTU = 1420");
        text += "PresharedKey = " + QString::fromLatin1(QByteArray(32, 'c').toBase64()) + "\n";
        QVERIFY(mxvpn::validateWireGuardImport(text).valid());
    }
    void invalid_data() {
        QTest::addColumn<QString>("text");
        QTest::newRow("missing-key") << fixture().replace(QRegularExpression("PrivateKey = [^\\n]+"), "");
        QTest::newRow("bad-key") << fixture().replace(QRegularExpression("PrivateKey = [^\\n]+"), "PrivateKey = SECRET_MUST_NOT_APPEAR");
        QTest::newRow("zero-key") << fixture().replace(QRegularExpression("PrivateKey = [^\\n]+"), "PrivateKey = " + QString::fromLatin1(QByteArray(32, '\0').toBase64()));
        QTest::newRow("bad-cidr") << fixture().replace("10.2.0.2/32", "10.2.0.2/33");
        QTest::newRow("bad-dns") << fixture().replace("10.2.0.1", "999.2.0.1");
        QTest::newRow("missing-dns") << fixture().replace("DNS = 10.2.0.1\n", "");
        QTest::newRow("partial-tunnel") << fixture().replace("0.0.0.0/0, ::/0", "0.0.0.0/0");
        QTest::newRow("script-hook") << fixture().replace("DNS = 10.2.0.1", "DNS = 10.2.0.1\nPostUp = executable");
        QTest::newRow("duplicate-key") << fixture() + "PublicKey = ignored\n";
        QTest::newRow("wrong-section") << fixture().replace("[Peer]\n", "[Peer]\nAddress = 10.2.0.3/32\n");
        QTest::newRow("multiple-peers") << fixture() + "[Peer]\nPublicKey = ignored\n";
        QTest::newRow("missing-port") << fixture().replace(":51820", "");
        QTest::newRow("zero-port") << fixture().replace(":51820", ":0");
        QTest::newRow("large-port") << fixture().replace(":51820", ":65536");
        QTest::newRow("bad-keepalive") << fixture().replace("PersistentKeepalive = 25", "PersistentKeepalive = -1");
        QTest::newRow("too-small-mtu") << fixture().replace("DNS = 10.2.0.1", "DNS = 10.2.0.1\nMTU = 576");
        QTest::newRow("oversize") << fixture() + QString(65536, ' ');
        QTest::newRow("nul") << fixture() + QChar('\0');
    }
    void invalid() {
        QFETCH(QString, text);
        const auto result = mxvpn::validateWireGuardImport(text);
        QVERIFY(!result.valid());
        QVERIFY(result.fields.isEmpty());
        QVERIFY(!result.error.contains("SECRET_MUST_NOT_APPEAR"));
        QVERIFY(!result.error.contains(QByteArray(32, 'a').toBase64()));
    }
};
QTEST_GUILESS_MAIN(ImportTests)
#include "importTests.moc"
