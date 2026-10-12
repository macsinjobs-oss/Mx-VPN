// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QtGlobal>
#include <QByteArray>
#include <QString>

namespace mxvpn {
// Authenticate the kernel-provided peer audit token against the installed,
// administrator-pinned app signature. No permissive fallback exists.
bool authorizeHelperClient(qintptr descriptor);
bool ensureHelperRuntimeDirectory();
bool ensureWireguardRuntimeDirectory();
// Identity check separated from production trust-file loading for isolated tests.
bool authenticatePinnedHelperPeer(qintptr descriptor, const QString &expectedPath, const QByteArray &expectedHash);
}
