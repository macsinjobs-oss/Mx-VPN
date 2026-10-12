// SPDX-License-Identifier: GPL-3.0-or-later
#include <QCoreApplication>
#include <QFile>
#include <QTextStream>
#include "core/utils/mxWireGuardValidation.h"

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QTextStream output(stdout);
    if (argc != 2) {
        output << "Usage: mx_validate_config <local-conf-path>\n";
        return 2;
    }
    QFile file(QString::fromLocal8Bit(argv[1]));
    if (!file.open(QIODevice::ReadOnly) || file.size() > 65536) {
        output << "Cannot read a bounded local configuration.\n";
        return 2;
    }
    const auto data = file.readAll();
    const auto text = QString::fromUtf8(data);
    if (text.toUtf8() != data) {
        output << "Configuration must use UTF-8 text.\n";
        return 1;
    }
    const auto result = mxvpn::validateWireGuardImport(text);
    if (!result.valid()) {
        output << result.error << '\n';
        return 1;
    }
    output << "Configuration valid for single-peer full-tunnel WireGuard import. No keys displayed or copied.\n";
    return 0;
}
