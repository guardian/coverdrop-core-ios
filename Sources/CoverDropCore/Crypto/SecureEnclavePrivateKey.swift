import Foundation

public enum SecureEnclavePrivateKeyError: Error {
    case cannotFindKey(error: Int32)
    case cannotGetData
    case cannotSetAccess
}

public struct SecureEnclavePrivateKey: Equatable {
    public var privateKey: SecKey
}

public extension SecureEnclavePrivateKey {
    static func createKey(name: String) async throws -> SecureEnclavePrivateKey {
        let load = Task {
            guard let tag = name.data(using: .utf8) else {
                throw SecureEnclavePrivateKeyError.cannotGetData
            }

            guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .privateKeyUsage,
                nil
            ) else {
                throw SecureEnclavePrivateKeyError.cannotSetAccess
            }
            let attributes: NSDictionary = [
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits: 256,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecPrivateKeyAttrs: [
                    kSecAttrIsPermanent: true,
                    kSecAttrApplicationTag: tag,
                    kSecAttrAccessControl: access
                ]
            ]

            // We need to delete any existing key first,
            // as you cannot store multiple keys with the same name
            // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys

            let query: NSDictionary = [
                kSecClass: kSecClassKey,
                kSecAttrApplicationTag: tag,
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecReturnRef: true
            ]

            // we ignore any errors from this, as its possible a key may not yet exist
            SecItemDelete(query)

            var error: Unmanaged<CFError>?

            guard let privateKey: SecKey = SecKeyCreateRandomKey(attributes, &error) else {
                throw error!.takeRetainedValue() as Error
            }

            return self.init(privateKey: privateKey)
        }

        return try await load.value
    }

    static func loadDefaultKey() async throws -> SecureEnclavePrivateKey {
        try await SecureEnclavePrivateKey.loadKey(name: EncryptedStorage.fileName)
    }

    static func loadKey(name: String) async throws -> SecureEnclavePrivateKey {
        let load = Task {
            guard let tag = name.data(using: .utf8) else {
                throw SecureEnclavePrivateKeyError.cannotGetData
            }
            let query: NSDictionary = [
                kSecClass: kSecClassKey,
                kSecAttrApplicationTag: tag,
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecReturnRef: true
            ]

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess else {
                throw SecureEnclavePrivateKeyError.cannotFindKey(error: status)
            }

            return self.init(privateKey: item as! SecKey)
        }
        return try await load.value
    }
}
