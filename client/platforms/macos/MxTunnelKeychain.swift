// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Security

enum MxTunnelKeychain {
    static func payload(reference: Data) -> Data? {
        let query: [CFString: Any] = [
            kSecValuePersistentRef: reference,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }
}
