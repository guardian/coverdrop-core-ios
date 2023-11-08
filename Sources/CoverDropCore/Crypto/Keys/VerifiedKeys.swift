import Foundation
import Sodium

enum VerificationError: Error {
    case couldNotGetKeyFromUnverified
    case noJournalistKeysPresent
    case couldNotVerifyOrganizationKey
}

/// This contains a verified set of public keys, journalist profiles, and the default journalistId
/// The public keys are verified, the profiles and default journalist are implicitly trusted
public struct VerifiedPublicKeys {
    public var journalistProfiles: [JournalistProfile]
    public let defaultJournalistId: String?
    public let verifiedHierarchies: [VerifiedPublicKeysHierarchy]

    /// Creates a `VerifiedPublicKeys` from `PublicKeysData`
    /// - Parameters:
    ///   - publicKeysData: An instance of PublicKeysData, this can be a response from the `public-keys` API endpoint, or a cached version from disk.
    ///   - trustedOrganizationPublicKeys: A list of `TrustedOrganizationPublicKey`, these are got from the app package bundle, so baked into the build.
    ///   - currentTime: the current time the app is running in
    /// - Returns: An instance of `VerifiedPublicKeys`
    init?(publicKeysData: PublicKeysData, trustedOrganizationPublicKeys: [TrustedOrganizationPublicKey], currentTime: Date) {
        let verifiedHierarchies: [VerifiedPublicKeysHierarchy] = publicKeysData.keys.compactMap { keyHierarchy in
            VerifiedPublicKeysHierarchy(keyHierarchy: keyHierarchy, trustedOrganizationPublicKeys: trustedOrganizationPublicKeys, currentTime: currentTime)
        }
        let defaultJournalistId = publicKeysData.defaultJournalistId

        self.journalistProfiles = publicKeysData.journalistProfiles
        self.defaultJournalistId = defaultJournalistId
        self.verifiedHierarchies = verifiedHierarchies
    }

    public func allOrganizationKeysFromAllHierarchies() -> [TrustedOrganizationPublicKey] {
        var trustedOrganizationPublicKeys: [TrustedOrganizationPublicKey] = []
        self.verifiedHierarchies.forEach { verifiedPublicKeysHierarchies in
            trustedOrganizationPublicKeys.append(verifiedPublicKeysHierarchies.organizationPublicKey)
        }
        return trustedOrganizationPublicKeys
    }

    public func allCoverNodeKeysFromAllHierarchies() -> [VerifiedCoverNodeKeyHierarchy] {
        var verifiedCoverNodeKeyHierarchies: [VerifiedCoverNodeKeyHierarchy] = []
        self.verifiedHierarchies.forEach { verifiedPublicKeysHierarchies in
            verifiedPublicKeysHierarchies.verifiedCoverNodeKeyHierarchies.forEach { coverNodeKeys in
                verifiedCoverNodeKeyHierarchies.append(coverNodeKeys)
            }
        }
        return verifiedCoverNodeKeyHierarchies
    }

    public func mostRecentCoverNodeMessagingKeysFromAllHierarchies() -> [CoverNodeIdentity: CoverNodeMessagingPublicKey] {
        var coverNodeInstanceMessageKeys: [CoverNodeIdentity: CoverNodeMessagingPublicKey] = [:]
        let allCoverNodes = self.allCoverNodeKeysFromAllHierarchies()

        for coverNodes in allCoverNodes {
            if let keysHierarchy = coverNodes.getMostRecentCoverNodeKeyHierarchy() {
                for (coverNodeId, value) in keysHierarchy {
                    if let recentKey = value.getMostRecentMessageKey() {
                        coverNodeInstanceMessageKeys.updateValue(recentKey, forKey: coverNodeId)
                    }
                }
            }
        }
        return coverNodeInstanceMessageKeys
    }

    /// This gets all the public keys for each journalist regardless of the key hierarchy the keys are in.
    /// This is required because when we try and decode incoming messages, it is possible for them to be encrypted with older keys, so we must try all keys.
    /// - Returns: An Dictionary of `String` -> `[VerifiedJournalistPublicKeysGroup]` where string is the journalist id.
    public func allPublicKeysForJournalistsFromAllHierarchies() -> [String: [VerifiedJournalistPublicKeysGroup]] {
        var journalistPublicKeys: [String: [VerifiedJournalistPublicKeysGroup]] = [:]

        self.verifiedHierarchies.forEach { verifiedPublicKeysHierarchies in
            verifiedPublicKeysHierarchies.verifiedJournalistKeyHierarchies.forEach { verifiedPublicKeysHierarchy in
                for (journalistId, publicKey) in verifiedPublicKeysHierarchy.keys {
                    journalistPublicKeys.updateValue(publicKey, forKey: journalistId)
                }
            }
        }
        return journalistPublicKeys
    }

    public func allPublicKeysForJournalistId(journalistId: String) -> [VerifiedJournalistPublicKeysGroup]? {
        if let journalistPublicKeys = self.allPublicKeysForJournalistsFromAllHierarchies()[journalistId],
           journalistPublicKeys.isEmpty == false
        {
            return journalistPublicKeys

        } else {
            return nil
        }
    }

    /// This gets all the coverNode Id keys for each CoverNode instance regardless of the key hierarchy the keys are in.
    /// - Returns: An Dictionary of `CoverNodeInstanceId` -> `[CoverNodeIdPublicKey]` where string is the coverNode instance id.
    func getAllCoverNodeIdKeys() -> [CoverNodeIdentity: [CoverNodeIdPublicKey]] {
        var coverNodeIdKeys: [String: [CoverNodeIdPublicKey]] = [:]

        self.verifiedHierarchies.forEach { verifiedKeys in
            verifiedKeys.verifiedCoverNodeKeyHierarchies.forEach { coverNodeKeysFamily in
                if let newKeys: [String: [CoverNodeIdPublicKey]] = coverNodeKeysFamily.getAllCoverNodeIdKeys() {
                    coverNodeIdKeys.merge(newKeys, uniquingKeysWith: { current, new in
                        current + new
                    })
                }
            }
        }
        return coverNodeIdKeys
    }

    /// This gets all the coverNode Id keys for each CoverNode instance regardless of the key hierarchy the keys are in.
    /// - Returns: An Dictionary of `String` -> `[CoverNodeMessagingPublicKey]` where string is the coverNode instance id.
    func getAllCoverNodeMessagingKeys() -> [CoverNodeIdentity: [CoverNodeMessagingPublicKey]] {
        var coverNodeIdKeys: [CoverNodeIdentity: [CoverNodeMessagingPublicKey]] = [:]

        self.verifiedHierarchies.forEach { verifiedKeys in
            verifiedKeys.verifiedCoverNodeKeyHierarchies.forEach { coverNodeKeysFamily in
                if let newKeys: [String: [CoverNodeMessagingPublicKey]] = coverNodeKeysFamily.getAllCoverNodeMessagingKeys() {
                    coverNodeIdKeys.merge(newKeys, uniquingKeysWith: { current, new in
                        current + new
                    })
                }
            }
        }
        return coverNodeIdKeys
    }
}

/// This is a verified Public Keys Hierarchy. This means that all the keys have be verified against their signing keys
/// all the way to the root `TrustedOrganizationPublicKey`
public struct VerifiedPublicKeysHierarchy {
    public var verifiedJournalistKeyHierarchies: [VerifiedJournalistPublicKeyHierarchy]
    public var organizationPublicKey: TrustedOrganizationPublicKey
    public var verifiedCoverNodeKeyHierarchies: [VerifiedCoverNodeKeyHierarchy]

    /// This gets the mst recent verified CoverNode key hierarcy by `notValidAfter` date
    /// - Returns: A `VerifiedCoverNodeKeyHierarchy`
    public func getMostRecentCoverNodeHierarchy() -> VerifiedCoverNodeKeyHierarchy? {
        return self.verifiedCoverNodeKeyHierarchies.max(by: { $0.provisioningKey.notValidAfter < $1.provisioningKey.notValidAfter })
    }

    /// This gets all the public keys for each journalist for this key hierarchy.
    /// - Returns: An Dictionary of `String` -> `[VerifiedJournalistPublicKeysGroup]` where string is the journalist id.
    public func allPublicKeysForJournalists() -> [String: [VerifiedJournalistPublicKeysGroup]] {
        var keys: [String: [VerifiedJournalistPublicKeysGroup]] = [:]

        self.verifiedJournalistKeyHierarchies.forEach { journalistPublicKeys in
            for (journalistId, publicKey) in journalistPublicKeys.keys {
                keys.updateValue(publicKey, forKey: journalistId)
            }
        }
        return keys
    }

    /// Failable initialiser for a VerifiedPublicKeysHierarchy.
    /// - Parameters:
    ///   - keyHierarchy: The Key Hierarchy to verify
    ///   - trustedOrganizationPublicKeys: A list of `TrustedOrganizationPublicKey` to try and verify with
    ///   - currentTime: currentTime: the current time the app is running in
    /// - Returns: Returns a VerifiedPublicKeysHierarchy if successfully verified, or fails if it could not verify.
    init?(keyHierarchy: KeyHierarchy, trustedOrganizationPublicKeys: [TrustedOrganizationPublicKey], currentTime: Date) {
        let unverifiedOrganizationPublicKey = SelfSignedPublicSigningKey<Organization>(key: Sign.KeyPair.PublicKey(keyHierarchy.organizationPublicKey.key.bytes), certificate: Signature<Organization>.fromBytes(
            bytes: keyHierarchy.organizationPublicKey.certificate.bytes), notValidAfter: keyHierarchy.organizationPublicKey.notValidAfter.date, now: currentTime)

        guard let orgPublicKey = unverifiedOrganizationPublicKey,
              let trustedOrganizationPublicKey: TrustedOrganizationPublicKey = VerifiedPublicKeysHierarchy.verifyOrganizationPublicKey(orgPk: orgPublicKey, trustedOrgPks: trustedOrganizationPublicKeys)
        else {
            return nil
        }

        do {
            let coverNodesHierarchies: [VerifiedCoverNodeKeyHierarchy] = try VerifiedPublicKeysHierarchy.verifyCoverNodeHierarchy(keyHierarchy: keyHierarchy, trustedOrganizationPublicKey: trustedOrganizationPublicKey, currentTime: currentTime)

            let verifiedJournalistPublicKeysHierarchry: [VerifiedJournalistPublicKeyHierarchy] = try VerifiedPublicKeysHierarchy.verifyJournalistKeysHierarchy(keyHierarchy: keyHierarchy, trustedOrganizationPublicKey: trustedOrganizationPublicKey, currentTime: currentTime)

            if keyHierarchy.journalists.isEmpty {
                return nil
            } else {
                self.verifiedJournalistKeyHierarchies = verifiedJournalistPublicKeysHierarchry
                self.organizationPublicKey = trustedOrganizationPublicKey
                self.verifiedCoverNodeKeyHierarchies = coverNodesHierarchies
            }
        } catch {
            return nil
        }
    }

    /// Verify a list of coverNode Key Hierarchies from a KeyHierarchy
    /// - Parameters:
    ///   - keyHierarchy: The Key Hierarchy to verify
    ///   - trustedOrganizationPublicKeys: A list of `TrustedOrganizationPublicKey` to try and verify with
    ///   - currentTime: currentTime: the current time the app is running in
    /// - Returns: A list of VerifiedCoverNodeKeyHierarchy  if succesfully verified
    /// - Throws: An error if verification was unsuccessful
    public static func verifyCoverNodeHierarchy(keyHierarchy: KeyHierarchy, trustedOrganizationPublicKey: TrustedOrganizationPublicKey, currentTime: Date) throws -> [VerifiedCoverNodeKeyHierarchy] {
        return try keyHierarchy.coverNodes.map { coverNodeHierarchy in

            let coverNodeProvisioningKey = coverNodeHierarchy.provisioningPublicKey

            let verifiedCoverNodeProvisioningKey: CoverNodeProvisioningKey = try CoverNodeProvisioningKey.fromUnverified(unverifiedKey: coverNodeProvisioningKey, signingKey: trustedOrganizationPublicKey, now: currentTime)

            var coverNodeInstances: [CoverNodeIdentity: [VerifiedCoverNodeKeysFamily]] = [:]

            try coverNodeHierarchy.covernodes.forEach { coverNodeId, coverNodeKeysFamilies in
                let coverNodeKeys = try coverNodeKeysFamilies.map { family in
                    let verifiedCoverNodeIdKey: CoverNodeIdPublicKey = try CoverNodeIdPublicKey.fromUnverified(unverifiedKey: family.idPk, signingKey: verifiedCoverNodeProvisioningKey, now: currentTime)
                    let coverNodeMessageKeys: [CoverNodeMessagingPublicKey] = try extractCoverNodeMessageKeys(keysGroup: family.msgPks, verifiedCoverNodeIdKey: verifiedCoverNodeIdKey, now: currentTime)
                    return VerifiedCoverNodeKeysFamily(id: verifiedCoverNodeIdKey, msg: coverNodeMessageKeys)
                }
                coverNodeInstances.updateValue(coverNodeKeys, forKey: coverNodeId)
            }
            let verifiedCoverNodeKeyHierarchy: VerifiedCoverNodeKeyHierarchy = .init(idPublicKeys: coverNodeInstances, provisioningKey: verifiedCoverNodeProvisioningKey)
            return verifiedCoverNodeKeyHierarchy
        }
    }

    /// Verify a list of Journalist Public Key Hierarchies from a KeyHierarchy
    /// - Parameters:
    ///   - keyHierarchy: The Key Hierarchy to verify
    ///   - trustedOrganizationPublicKeys: A list of `TrustedOrganizationPublicKey` to try and verify with
    ///   - currentTime: currentTime: the current time the app is running in
    /// - Returns: A list of VerifiedJournalistPublicKeyHierarchy  if succesfully verified
    /// - Throws: An error if verification was unsuccessful
    public static func verifyJournalistKeysHierarchy(keyHierarchy: KeyHierarchy, trustedOrganizationPublicKey: TrustedOrganizationPublicKey, currentTime: Date) throws -> [VerifiedJournalistPublicKeyHierarchy] {
        try keyHierarchy.journalists.map { journalistHierarchy in

            let journalistProvisioningKey = journalistHierarchy.provisioningPublicKey

            let verifiedJournalistProvisioningKey: JournalistProvisioningKey = try JournalistProvisioningKey.fromUnverified(unverifiedKey: journalistProvisioningKey, signingKey: trustedOrganizationPublicKey, now: currentTime)

            var journalists: [String: [VerifiedJournalistPublicKeysGroup]] = [:]

            try journalistHierarchy.journalists.forEach { journalistId, journalistKeysFamily in

                let verifiedJournalistPublicKeysGroup: [VerifiedJournalistPublicKeysGroup] = try verifyJournalistPublicKeys(keysGroup: journalistKeysFamily, journalistProvisioningKey: verifiedJournalistProvisioningKey, now: currentTime)
                journalists.updateValue(verifiedJournalistPublicKeysGroup, forKey: journalistId)
            }
            return VerifiedJournalistPublicKeyHierarchy(keys: journalists, provisioningKey: verifiedJournalistProvisioningKey)
        }
    }

    /// Verifies an untrusted `OrganizationPublicKey` against a list of `TrustedOrganizationPublicKey`
    /// - Parameters:
    ///   - orgPk: A `OrganizationPublicKey` from the `public-keys` API response
    ///   - trustedOrgPks: A list of `TrustedOrganizationPublicKey` loaded from the app bundle
    /// - Returns: A `TrustedOrganizationPublicKey` if verification was succesful
    public static func verifyOrganizationPublicKey(
        orgPk: OrganizationPublicKey,
        trustedOrgPks: [TrustedOrganizationPublicKey]
    ) -> TrustedOrganizationPublicKey? {
        if let trustedKey = trustedOrgPks.first(where: { trustedKey in
            orgPk.key == trustedKey.key
        }) {
            return trustedKey
        } else {
            return nil
        }
    }

    /// This verifies a list of `JournalistKeysFamily` against the `JournalistProvisioningKey`
    /// - Parameters:
    ///   - keysGroup: A list of `JournalistProvisioningKey`
    ///   - journalistProvisioningKey: A `JournalistProvisioningKey`
    ///   - now: the current time in the app
    /// - Returns: a list of `VerifiedJournalistPublicKeysGroup`
    /// - Throws: if verification was unsuccesful
    private static func verifyJournalistPublicKeys(keysGroup: [JournalistKeysFamily], journalistProvisioningKey: JournalistProvisioningKey, now: Date) throws -> [VerifiedJournalistPublicKeysGroup] {
        return try keysGroup.map { key in
            let unverifiedIdKey: UnverifiedSignedPublicSigningKeyData = key.idPk
            let verifiedIdKey: JournalistIdPublicKey = try JournalistIdPublicKey.fromUnverified(unverifiedKey: unverifiedIdKey, signingKey: journalistProvisioningKey, now: now)

            let verifiedMessageKeys: [JournalistMessagingPublicKey] = try verifyJournalistMessageKeys(keysGroup: key.msgPks, verifiedJournalistIdPublicKey: verifiedIdKey, now: now)

            return VerifiedJournalistPublicKeysGroup(id: verifiedIdKey,
                                                     msg: verifiedMessageKeys)
        }
    }

    /// Verifies a list of `UnverifiedSignedPublicEncryptionKeyData` against the supplied `JournalistIdPublicKey`
    /// - Parameters:
    ///   - keysGroup: a list of `UnverifiedSignedPublicEncryptionKeyData`
    ///   - verifiedJournalistIdPublicKey: a verified `JournalistIdPublicKey`
    ///   - now: the current time in the app
    /// - Returns: a list of `JournalistMessagingPublicKey`
    private static func verifyJournalistMessageKeys(keysGroup: [UnverifiedSignedPublicEncryptionKeyData], verifiedJournalistIdPublicKey: JournalistIdPublicKey, now: Date) throws -> [JournalistMessagingPublicKey] {
        return try keysGroup.map { messageKey in
            let verifiedMessageKey: JournalistMessagingPublicKey = try JournalistMessagingPublicKey.fromUnverified(unverifiedMessageKey: messageKey, signingKey: verifiedJournalistIdPublicKey, now: now)
            return verifiedMessageKey
        }
    }

    /// Verifies a list of `UnverifiedSignedPublicEncryptionKeyData` against the supplied `CoverNodeIdPublicKey`
    /// - Parameters:
    ///   - keysGroup: a list of `UnverifiedSignedPublicEncryptionKeyData`
    ///   - verifiedCoverNodeIdKey: a verified `CoverNodeIdPublicKey`
    ///   - now: the current time in the app
    /// - Returns: a list of `CoverNodeMessagingPublicKey`
    private static func extractCoverNodeMessageKeys(keysGroup: [UnverifiedSignedPublicEncryptionKeyData], verifiedCoverNodeIdKey: CoverNodeIdPublicKey, now: Date) throws -> [CoverNodeMessagingPublicKey] {
        return try keysGroup.map { messageKey in
            let verifiedMessageKey: CoverNodeMessagingPublicKey = try CoverNodeMessagingPublicKey.fromUnverified(unverifiedMessageKey: messageKey, signingKey: verifiedCoverNodeIdKey, now: now)
            return verifiedMessageKey
        }
    }
}

/// A `VerifiedJournalistPublicKeysGroup`
public struct VerifiedJournalistPublicKeysGroup {
    let id: JournalistIdPublicKey
    let msg: [JournalistMessagingPublicKey]

    /// This gets the most recent message key by `notValidAfter` date
    /// - Returns: A `JournalistMessagingPublicKey` if one is available
    public func getMostRecentMessageKey() -> JournalistMessagingPublicKey? {
        return self.msg.max(by: { $0.notValidAfter < $1.notValidAfter })
    }
}

/// A `VerifiedJournalistPublicKeyHierarchy`
public struct VerifiedJournalistPublicKeyHierarchy {
    public let keys: [String: [VerifiedJournalistPublicKeysGroup]]
    public let provisioningKey: JournalistProvisioningKey

    /// This gets the most recent journalist public key hierarchy by `notValidAfter` date
    /// - Returns: A list if journalist id -> VerifiedJournalistPublicKeysGroup
    public func getMostRecentVerifiedJournalistPublicKeyHierarchy() -> [String: VerifiedJournalistPublicKeysGroup]? {
        var journalistKey: [String: VerifiedJournalistPublicKeysGroup] = [:]
        self.keys.forEach { journalist, key in
            if let mostRecentKey = key.max(by: { $0.id.notValidAfter < $1.id.notValidAfter }) {
                journalistKey.updateValue(mostRecentKey, forKey: journalist)
            }
        }
        return journalistKey
    }
}

public typealias CoverNodeIdentity = String

/// A `VerifiedCoverNodeKeysFamily`
public struct VerifiedCoverNodeKeysFamily {
    public let id: CoverNodeIdPublicKey
    public let msg: [CoverNodeMessagingPublicKey]

    /// This gets the most recent message key by `notValidAfter` date
    /// - Returns: `CoverNodeMessagingPublicKey` if available
    public func getMostRecentMessageKey() -> CoverNodeMessagingPublicKey? {
        return self.msg.max(by: { $0.notValidAfter < $1.notValidAfter })
    }
}

/// A `VerifiedCoverNodeKeyHierarchy`
public struct VerifiedCoverNodeKeyHierarchy {
    public let idPublicKeys: [String: [VerifiedCoverNodeKeysFamily]]
    public let provisioningKey: CoverNodeProvisioningKey

    /// This gets the most recent coverNode public key hierarchy by `notValidAfter` date for each coverNode instance
    /// - Returns: A list if  coverNode instance id -> VerifiedCoverNodeKeysFamily
    public func getMostRecentCoverNodeKeyHierarchy() -> [CoverNodeIdentity: VerifiedCoverNodeKeysFamily]? {
        var coverNodeKeys: [CoverNodeIdentity: VerifiedCoverNodeKeysFamily] = [:]
        self.idPublicKeys.forEach { coverNode, key in
            if let mostRecentKey = key.max(by: { $0.id.notValidAfter < $1.id.notValidAfter }) {
                coverNodeKeys.updateValue(mostRecentKey, forKey: coverNode)
            }
        }
        return coverNodeKeys
    }

    /// This gets all the coverNode Id keys for each CoverNode instance in the current hierarcy
    /// - Returns: An Dictionary of `String` -> `[CoverNodeIdPublicKey]` where string is the coverNode instance id.
    public func getAllCoverNodeIdKeys() -> [CoverNodeIdentity: [CoverNodeIdPublicKey]]? {
        var coverNodeKeys: [CoverNodeIdentity: [CoverNodeIdPublicKey]] = [:]
        self.idPublicKeys.forEach { coverNodeInstanceId, coverNodeKeysFamilies in
            coverNodeKeysFamilies.forEach { coverNodeKeysFamily in
                let mostRecentKey = coverNodeKeysFamily.id
                coverNodeKeys[coverNodeInstanceId, default: []].append(mostRecentKey)
            }
        }
        return coverNodeKeys
    }

    /// This gets all the coverNode Messaging keys for each CoverNode instance in the current hierarcy
    /// - Returns: An Dictionary of `String` -> `[CoverNodeIdPublicKey]` where string is the coverNode instance id.
    public func getAllCoverNodeMessagingKeys() -> [CoverNodeIdentity: [CoverNodeMessagingPublicKey]]? {
        var coverNodeKeys: [CoverNodeIdentity: [CoverNodeMessagingPublicKey]] = [:]
        self.idPublicKeys.forEach { coverNodeInstanceId, coverNodeKeysFamilies in
            coverNodeKeysFamilies.forEach { coverNodeKeysFamily in
                if let mostRecentKey = coverNodeKeysFamily.getMostRecentMessageKey() {
                    coverNodeKeys[coverNodeInstanceId, default: []].append(mostRecentKey)
                }
            }
        }
        return coverNodeKeys
    }
}
