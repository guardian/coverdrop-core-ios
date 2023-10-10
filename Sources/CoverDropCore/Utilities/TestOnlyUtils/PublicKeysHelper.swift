import Foundation
import Sodium

public enum KeysError: Error {
    case cannotFindFileError
}

public enum MockDate {
    public static func currentTime() -> Date {
        do {
            if let generatedAtDate = try PublicKeysHelper.readLocalGeneratedAtFile() {
                return generatedAtDate
            } else {
                return Date()
            }
        } catch {
            return Date()
        }
    }
}

/// This helper is used to load the public keys fixture data from disk for the purpose of unit and UI testing
/// It is located here because our tests are defined across multiple packages, and CoverDropCore is a common dependency of them all
public class PublicKeysHelper {
    // swiftlint:disable force_try

    public let testKeys: VerifiedPublicKeys

    public static let shared = PublicKeysHelper()

    private init() {
        let config = ApplicationConfig.config
        PublicDataRepository.setup(config)
        let publicKeysData = try! PublicKeysHelper.readLocalKeysFile()
        let trustedOrganizationSigningKeys = try! PublicKeysHelper.readLocalTrustedOrganizationKeys()
        let verifiedPublicKeysData = try! VerifiedPublicKeys(publicKeysData: publicKeysData, trustedOrganizationPublicKeys: trustedOrganizationSigningKeys, currentTime: MockDate.currentTime())
        testKeys = verifiedPublicKeysData!
    }

    public static func readLocalKeysFile() throws -> PublicKeysData {
        let data = try readLocalKeysJson()
        let keys = try JSONDecoder().decode(PublicKeysData.self, from: data)
        return keys
    }

    public static func readLocalKeysJson() throws -> Data {
        let name = "001_initial_state"
        guard let resourceUrl = Bundle.module.url(forResource: name, withExtension: ".json", subdirectory: "vectors/create_journalists/published_keys") else { throw KeysError.cannotFindFileError }
        let data = try Data(contentsOf: resourceUrl)
        return data
    }

    public static func readLocalMultipleMessagingKeysJson() throws -> Data {
        let name = "001_initial_state"
        guard let resourceUrl = Bundle.module.url(forResource: name, withExtension: ".json", subdirectory: "vectors/multiple_journalists_messaging_scenario/published_keys") else { throw KeysError.cannotFindFileError }
        let data = try Data(contentsOf: resourceUrl)
        return data
    }

    public static func readLocalTrustedOrganizationKeys() throws -> [TrustedOrganizationPublicKey] {
        if let config = PublicDataRepository.appConfig {
            let trustedRootKeys = try config.organizationPublicKeys()
            return trustedRootKeys
        } else {
            return []
        }
    }

    public static func readLocalSecretsFile(path: String) throws -> UnverifiedSignedPublicSigningKeyDataKeyAndType {
        let name = path
        guard let resourceUrl = Bundle.module.url(forResource: name, withExtension: ".json", subdirectory: "keys") else { throw KeysError.cannotFindFileError }
        let data = try Data(contentsOf: resourceUrl)
        let keyData = try JSONDecoder().decode(UnverifiedSignedPublicSigningKeyDataKeyAndType.self, from: data)
        return keyData
    }

    public static func readLocalGeneratedAtFile() throws -> Date? {
        let name = "keys_generated_at"
        guard let resourceUrl = Bundle.module.url(forResource: name, withExtension: ".txt", subdirectory: "keys") else { throw KeysError.cannotFindFileError }
        let data = try Data(contentsOf: resourceUrl)
        if let dateString = String(data: data, encoding: .utf8) {
            return DateFormats.validateDate(date: dateString)
        }
        return nil
    }

    public static func getTestOrgKey() -> TrustedOrganizationPublicKey {
        return PublicKeysHelper.shared.testKeys.allOrganizationKeysFromAllHierarchies().sorted(by: { $0.notValidAfter < $1.notValidAfter }).first!
    }

    public static func getTestCovernodeIdKey() -> CoverNodeIdPublicKey? {
        let keyHierarchy = PublicKeysHelper.shared.testKeys.allCoverNodeKeysFromAllHierarchies().sorted(by: { $0.provisioningKey.notValidAfter < $1.provisioningKey.notValidAfter }).first!

        let mostRecentCoverNodeId = keyHierarchy.idPublicKeys["covernode_001"]?.max(by: { $0.id.notValidAfter < $1.id.notValidAfter })

        return mostRecentCoverNodeId?.id
    }

    public static func getTestCovernodeKeyHierarchy() -> [VerifiedCoverNodeKeyHierarchy] {
        let keyHierarchy = PublicKeysHelper.shared.testKeys.verifiedHierarchies.first?.verifiedCoverNodeKeyHierarchies
        return keyHierarchy!
    }

    public static func getTestCovernodeMessageKey() -> CoverNodeMessagingPublicKey? {
        let keyHierarchy = PublicKeysHelper.shared.testKeys.allCoverNodeKeysFromAllHierarchies().sorted(by: { $0.provisioningKey.notValidAfter < $1.provisioningKey.notValidAfter }).first!

        let mostRecentCoverNodeId = keyHierarchy.idPublicKeys["covernode_001"]?.max(by: { $0.id.notValidAfter < $1.id.notValidAfter })

        return mostRecentCoverNodeId?.getMostRecentMessageKey()
    }

    public var testDefaultJournalist: JournalistKeyData? {
        let keys = try? MessageRecipients(verifiedPublicKeys: PublicKeysHelper.shared.testKeys, excludingDefaultRecipient: false).journalists
        return keys?.first(where: { value -> Bool in
            value.recipientId == "static_test_journalist"
        })
    }

    public var getTestDesk: JournalistKeyData? {
        let keys = try? MessageRecipients(verifiedPublicKeys: PublicKeysHelper.shared.testKeys, excludingDefaultRecipient: false).desks

        return keys?.first(where: { value -> Bool in
            value.recipientId == "generated_test_desk"
        }
        )
    }

    public var getTestJournalistMessageKey: JournalistMessagingPublicKey? {
        return testDefaultJournalist?.getMessageKey()
    }

    public func getTestJournalistMessageSecretKey() throws -> SecretEncryptionKey<JournalistMessaging> {
        // this is the secret key for the default recipient
        let data = try PublicKeysHelper.readLocalSecretsFile(path: "journalist_msg.sec")
        return SecretEncryptionKey(key: Box.KeyPair.SecretKey(data.key.bytes))
    }

    public func getTestCovernodeMessageSecretKey() throws -> SecretEncryptionKey<CoverNodeMessaging> {
        // this is the secret key for "covernode_message"
        let data = try PublicKeysHelper.readLocalSecretsFile(path: "covernode_msg.sec")
        return SecretEncryptionKey(key: Box.KeyPair.SecretKey(data.key.bytes))
    }

    public func getTestUserMessageSecretKey() throws -> SecretEncryptionKey<User> {
        // this is the secret key for the default recipient
        let data = try PublicKeysHelper.readLocalSecretsFile(path: "user.sec")
        return SecretEncryptionKey(key: Box.KeyPair.SecretKey(data.key.bytes))
    }

    public func getTestUserMessagePublicKey() throws -> PublicEncryptionKey<User> {
        // this is the secret key for the default recipient
        let data = try PublicKeysHelper.readLocalSecretsFile(path: "user.pub")
        return PublicEncryptionKey(key: Box.KeyPair.SecretKey(data.key.bytes))
    }
}
