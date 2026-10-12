#include <QtTest>
#include "core/utils/mxIpLookup.h"
class LookupTests : public QObject {
    Q_OBJECT
private slots:
    void parsesObservedTrace() {
        const auto result = mxvpn::parseIpTrace("fl=abc\nip=149.40.62.19\nloc=US\ntls=TLSv1.3\n");
        QCOMPARE(result.first, QString("149.40.62.19"));
        QCOMPARE(result.second, QString("US"));
    }
    void rejectsMalformedAddressAndCountry() {
        QVERIFY(mxvpn::parseIpTrace("ip=script\nloc=US\n").first.isEmpty());
        QVERIFY(mxvpn::parseIpTrace("ip=149.40.62.19\nloc=us\n").first.isEmpty());
    }
    void boundsProviderResponse() {
        QVERIFY(mxvpn::parseIpTrace(QByteArray(20000, 'x')).first.isEmpty());
    }
};
QTEST_GUILESS_MAIN(LookupTests)
#include "lookupTests.moc"
