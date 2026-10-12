#include <QtTest>
#include "core/utils/mxTrafficSnapshot.h"

class TrafficTests : public QObject {
    Q_OBJECT
private slots:
    void firstSampleHasTotalsWithoutInventedSpeed() {
        mxvpn::TrafficSnapshot stats;
        stats.sample(5000, 1000, 100);
        QCOMPARE(stats.receivedBytes, quint64(5000));
        QCOMPARE(stats.sentBytes, quint64(1000));
        QCOMPARE(stats.downloadPerSecond, 0.0);
    }
    void usesActualElapsedInterval() {
        mxvpn::TrafficSnapshot stats;
        stats.sample(5000, 1000, 100);
        stats.sample(17500, 6000, 2600);
        QCOMPARE(stats.downloadPerSecond, 5000.0);
        QCOMPARE(stats.uploadPerSecond, 2000.0);
    }
    void counterResetCannotBecomeUnsignedSpike() {
        mxvpn::TrafficSnapshot stats;
        stats.sample(100000, 50000, 1000);
        stats.sample(100, 50, 2000);
        QCOMPARE(stats.downloadPerSecond, 0.0);
        QCOMPARE(stats.uploadPerSecond, 0.0);
        stats.sample(1100, 550, 2500);
        QCOMPARE(stats.downloadPerSecond, 2000.0);
        QCOMPARE(stats.uploadPerSecond, 1000.0);
    }
    void zeroIntervalCannotDivideByZero() {
        mxvpn::TrafficSnapshot stats;
        stats.sample(100, 50, 1000);
        stats.sample(200, 100, 1000);
        QCOMPARE(stats.downloadPerSecond, 0.0);
        QCOMPARE(stats.uploadPerSecond, 0.0);
    }
};
QTEST_GUILESS_MAIN(TrafficTests)
#include "trafficTests.moc"
