// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Foundation/Foundation.h>
#import <Security/Security.h>

// App and extension share a provisioned keychain group. Preferences keep a ref only.
static inline NSData *mxStoreTunnelPayload(NSData *payload, NSData *previousReference)
{
    if (previousReference != nil) {
        NSDictionary *query = @{
            (__bridge id)kSecValuePersistentRef: previousReference,
            (__bridge id)kSecUseDataProtectionKeychain: @YES
        };
        const OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
            (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: payload});
        if (status == errSecSuccess) return previousReference;
        if (status != errSecItemNotFound) return nil;
    }
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"Mx VPN WireGuard",
        (__bridge id)kSecAttrAccount: NSUUID.UUID.UUIDString,
        (__bridge id)kSecAttrAccessGroup: @MX_KEYCHAIN_ACCESS_GROUP_STR,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecAttrSynchronizable: @NO,
        (__bridge id)kSecUseDataProtectionKeychain: @YES,
        (__bridge id)kSecValueData: payload,
        (__bridge id)kSecReturnPersistentRef: @YES
    };
    CFTypeRef reference = nil;
    const OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, &reference);
    if (status != errSecSuccess || reference == nil) return nil;
    return CFBridgingRelease(reference);
}
