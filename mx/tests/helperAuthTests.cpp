// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QCoreApplication>
#include <Security/Security.h>
#include <sys/socket.h>
#include <unistd.h>
#include "../../common/mxHelperSecurity.h"

class HelperAuthTests : public QObject {
    Q_OBJECT
private slots:
    void pinnedProcessIdentity() {
        SecCodeRef code = nullptr;
        QCOMPARE(SecCodeCopySelf(kSecCSDefaultFlags, &code), errSecSuccess);
        CFDictionaryRef information = nullptr;
        const auto status = SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information);
        CFRelease(code);
        QCOMPARE(status, errSecSuccess);
        auto identity = static_cast<CFDataRef>(CFDictionaryGetValue(information, kSecCodeInfoUnique));
        QVERIFY(identity != nullptr);
        const QByteArray hash(reinterpret_cast<const char *>(CFDataGetBytePtr(identity)), int(CFDataGetLength(identity)));
        CFRelease(information);
        int sockets[2] { -1, -1 };
        QCOMPARE(socketpair(AF_UNIX, SOCK_STREAM, 0, sockets), 0);
        const auto path = QCoreApplication::applicationFilePath();
        const bool accepted = mxvpn::authenticatePinnedHelperPeer(sockets[0], path, hash.toHex());
        const bool wrongHash = mxvpn::authenticatePinnedHelperPeer(sockets[0], path, QByteArray(40, '0'));
        const bool wrongPath = mxvpn::authenticatePinnedHelperPeer(sockets[0], path + ".other", hash.toHex());
        close(sockets[0]);
        close(sockets[1]);
        QVERIFY(accepted);
        QVERIFY(!wrongHash);
        QVERIFY(!wrongPath);
    }
    void malformedIdentityRejected() {
        QVERIFY(!mxvpn::authenticatePinnedHelperPeer(-1, "/test", QByteArray(40, '0')));
        QVERIFY(!mxvpn::authenticatePinnedHelperPeer(0, "/test", QByteArray(40, 'z')));
        QVERIFY(!mxvpn::authenticatePinnedHelperPeer(0, "/test", QByteArray(39, '0')));
        QVERIFY(!mxvpn::authenticatePinnedHelperPeer(0, "", QByteArray(40, '0')));
    }
    void productionRequiresAdministratorTrust() {
        QVERIFY(!mxvpn::authorizeHelperClient(-1));
        if (geteuid() != 0) {
            QVERIFY(!mxvpn::ensureHelperRuntimeDirectory());
            QVERIFY(!mxvpn::ensureWireguardRuntimeDirectory());
        }
    }
};
QTEST_GUILESS_MAIN(HelperAuthTests)
#include "helperAuthTests.moc"
