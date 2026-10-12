// SPDX-License-Identifier: GPL-3.0-or-later
#include "mxHelperSecurity.h"
#include <QByteArray>
#include <QString>
#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>
#include <mach/message.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>

namespace {
template<class T> struct OwnedCF {
    T value = nullptr;
    ~OwnedCF() { if (value) CFRelease(value); }
};
constexpr const char *trustDirectory = "/Library/Application Support/MxVPN";
constexpr const char *trustFile = "/Library/Application Support/MxVPN/client.cdhash";
constexpr const char *clientPath = "/Applications/Mx VPN.app/Contents/MacOS/Mx VPN";

bool rootOwned(const char *path, bool directory)
{
    struct stat metadata {};
    return lstat(path, &metadata) == 0 && metadata.st_uid == 0
        && (metadata.st_mode & (S_IWGRP | S_IWOTH)) == 0
        && (directory ? S_ISDIR(metadata.st_mode) : S_ISREG(metadata.st_mode));
}

QByteArray pinnedHash()
{
    if (!rootOwned(trustDirectory, true)) return {};
    const int descriptor = open(trustFile, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) return {};
    struct stat metadata {};
    if (fstat(descriptor, &metadata) != 0 || !S_ISREG(metadata.st_mode)
        || metadata.st_uid != 0 || (metadata.st_mode & (S_IWGRP | S_IWOTH))
        || metadata.st_size < 40 || metadata.st_size > 42) {
        close(descriptor);
        return {};
    }
    char buffer[43] {};
    const auto length = read(descriptor, buffer, sizeof(buffer));
    close(descriptor);
    if (length < 0) return {};
    const auto hash = QByteArray(buffer, int(length)).trimmed();
    if (hash.size() != 40) return {};
    for (char character : hash) {
        if (!((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f'))) return {};
    }
    return hash;
}
}

bool mxvpn::authorizeHelperClient(qintptr descriptor)
{
    if (descriptor < 0 || !rootOwned(clientPath, false)
        || !rootOwned("/Applications/Mx VPN.app", true)
        || !rootOwned("/Applications/Mx VPN.app/Contents", true)
        || !rootOwned("/Applications/Mx VPN.app/Contents/MacOS", true)) return false;
    const auto hash = pinnedHash();
    if (hash.isEmpty()) return false;
    return authenticatePinnedHelperPeer(descriptor, QString::fromLatin1(clientPath), hash);
}

bool mxvpn::ensureHelperRuntimeDirectory()
{
    if (geteuid() != 0) return false;
    if (mkdir("/var/run/mxvpn", 0755) != 0 && errno != EEXIST) return false;
    return rootOwned("/var/run/mxvpn", true);
}

bool mxvpn::ensureWireguardRuntimeDirectory()
{
    if (geteuid() != 0) return false;
    if (mkdir("/var/run/amneziawg", 0755) != 0 && errno != EEXIST) return false;
    return rootOwned("/var/run/amneziawg", true);
}

bool mxvpn::authenticatePinnedHelperPeer(qintptr descriptor, const QString &expectedPath, const QByteArray &hash)
{
    if (descriptor < 0 || expectedPath.isEmpty() || hash.size() != 40) return false;
    for (char character : hash) {
        if (!((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f'))) return false;
    }
    audit_token_t token {};
    socklen_t length = sizeof(token);
    if (getsockopt(int(descriptor), SOL_LOCAL, LOCAL_PEERTOKEN, &token, &length) != 0
        || length != sizeof(token)) return false;

    OwnedCF<CFDataRef> tokenData;
    tokenData.value = CFDataCreate(nullptr, reinterpret_cast<const UInt8 *>(&token), sizeof(token));
    const void *keys[] { kSecGuestAttributeAudit };
    const void *values[] { tokenData.value };
    OwnedCF<CFDictionaryRef> attributes;
    attributes.value = CFDictionaryCreate(nullptr, keys, values, 1,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    OwnedCF<SecCodeRef> code;
    if (SecCodeCopyGuestWithAttributes(nullptr, attributes.value, kSecCSDefaultFlags, &code.value) != errSecSuccess) return false;

    const auto requirementText = QByteArray("cdhash H\"") + hash + "\"";
    OwnedCF<CFStringRef> requirementString;
    requirementString.value = CFStringCreateWithCString(nullptr, requirementText.constData(), kCFStringEncodingUTF8);
    OwnedCF<SecRequirementRef> requirement;
    if (SecRequirementCreateWithString(requirementString.value, kSecCSDefaultFlags, &requirement.value) != errSecSuccess
        || SecCodeCheckValidity(code.value, kSecCSDefaultFlags, requirement.value) != errSecSuccess) return false;

    OwnedCF<CFDictionaryRef> information;
    if (SecCodeCopySigningInformation(code.value, kSecCSSigningInformation, &information.value) != errSecSuccess) return false;
    const auto executable = static_cast<CFURLRef>(CFDictionaryGetValue(information.value, kSecCodeInfoMainExecutable));
    if (!executable || CFGetTypeID(executable) != CFURLGetTypeID()) return false;
    OwnedCF<CFStringRef> path;
    path.value = CFURLCopyFileSystemPath(executable, kCFURLPOSIXPathStyle);
    return path.value && QString::fromCFString(path.value) == expectedPath;
}
