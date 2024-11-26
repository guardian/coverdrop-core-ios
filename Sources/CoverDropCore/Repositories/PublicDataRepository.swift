import Foundation
import Sodium

enum PublicDataRepositoryError: Error {
    case configNotAvailable
    case failedToGenerateRandomBytes
    case failedToGetCoverNodeMessageKeys
    case failedToCreateCoverMessage
    case failedToLoadDeadDrops
    case failedToLoadPublicKeys
    case failedToGetConfig
}

public typealias CoverMessageFactory = () throws -> MultiAnonymousBox<UserToCoverNodeMessageData>

public class PublicDataRepository: ObservableObject {
    @MainActor @Published public var coverDropServiceStatus: StatusData?
    @MainActor @Published public var areKeysAvailable: Bool = false
    @Published public var cacheEnabled: Bool = true
    public private(set) static var appConfig: CoverDropConfig?

    public class func setup(_ config: CoverDropConfig) {
        PublicDataRepository.appConfig = config
    }

    public static let shared = PublicDataRepository()

    private init() {
        guard PublicDataRepository.appConfig != nil else {
            fatalError("Error - you must call setup before accessing PublicDataRepository.shared")
        }
    }

    public func pollPublicKeysAndStatusApis() async throws {
        async let status: () = loadStatus()
        async let publicKeys = loadAndVerifyPublicKeys()

        try await status
        _ = try await publicKeys
    }

    public func loadStatus() async throws {
        guard let config = PublicDataRepository.appConfig else {
            throw PublicDataRepositoryError.configNotAvailable
        }
        if let currentStatus = try? await StatusRepository(config: config, urlSessionConfig: config.urlSessionConfig())
            .downloadAndUpdateAllCaches(cacheEnabled: config.cacheEnabled) {
            await MainActor.run {
                coverDropServiceStatus = currentStatus
            }
        }
    }

    public func loadDeadDrops() async throws -> VerifiedDeadDrops {
        guard let config = PublicDataRepository.appConfig else {
            throw PublicDataRepositoryError.configNotAvailable
        }

        let deadDropsOpt = try await DeadDropRepository(config: config, urlSession: config.urlSessionConfig())
            .downloadAndUpdateAllCaches(cacheEnabled: config.cacheEnabled)
        let verifiedPublicKeysOpt = try? await loadAndVerifyPublicKeys()

        guard let deadDrops = deadDropsOpt,
              let verifiedPublicKeys = verifiedPublicKeysOpt else {
            throw PublicDataRepositoryError.failedToLoadDeadDrops
        }

        // Load dead drops from journalists
        let verifiedDeadDropData = VerifiedDeadDrops.fromAllDeadDropData(
            deadDrops: deadDrops,
            verifiedKeys: verifiedPublicKeys
        )

        return verifiedDeadDropData
    }

    /// This loads and verifies the public key and dead drops from the API.
    /// Once verified, they are added to the `publicData` thus available throughtout the app.
    /// Public keys and dead drops can be updated at any time in the API, so we poll to stay up to date.
    @MainActor public func loadAndVerifyPublicKeys() async throws -> VerifiedPublicKeys {
        guard let config = PublicDataRepository.appConfig else {
            throw PublicDataRepositoryError.configNotAvailable
        }
        // Load public keys

        let publicKeysDataOpt = try? await PublicKeyRepository(
            config: config,
            urlSessionConfig: config.urlSessionConfig()
        ).downloadAndUpdateAllCaches(cacheEnabled: config.cacheEnabled)
        let trustedRootKeysOpt = try? PublicDataRepository.loadTrustedOrganizationPublicKeys(
            envType: config.envType,
            now: config.now()
        )

        guard let publicKeysData = publicKeysDataOpt,
              let trustedRootKeys = trustedRootKeysOpt else {
            throw PublicDataRepositoryError.failedToLoadPublicKeys
        }

        let verifiedPublicKeysData = VerifiedPublicKeys(
            publicKeysData: publicKeysData,
            trustedOrganizationPublicKeys: trustedRootKeys,
            currentTime: config.now()
        )
        areKeysAvailable = true
        return verifiedPublicKeysData
    }

    public func sendMessage(message: MultiAnonymousBox<UserToCoverNodeMessageData>,
                            withSecureDns _: Bool) async throws -> HTTPURLResponse {
        let dataOpt = message.asBytes().base64Encode()
        guard let data = dataOpt,
              let jsonData: Data = try? JSONEncoder().encode(data) else {
            throw UserToJournalistMessagingError.unableToBase64Encode
        }

        guard let config = PublicDataRepository.appConfig else {
            throw UserToJournalistMessagingError.failedToGetConfig
        }

        return try await UserToJournalistMessageWebRepository(
            session: config.urlSessionConfig(),
            baseUrl: config.messageBaseUrl
        ).sendMessage(jsonData: jsonData)
    }

    /// This dequeues a message from the `PrivateSendingQueue` and sends it to the user to journalist
    /// message api
    /// 1. dequeue message from privateSendingQueue
    /// 2. send to the api
    public func dequeueMessageAndSend(coverMessageFactory: CoverMessageFactory) async
        -> Result<Int, UserToJournalistMessagingError> {
        let privateSendingQueue = PrivateSendingQueueRepository.shared

        guard let config = PublicDataRepository.appConfig else {
            return .failure(UserToJournalistMessagingError.failedToGetConfig)
        }

        guard let message = try? await privateSendingQueue.peek() else {
            return .failure(UserToJournalistMessagingError.failedToPeekMessage)
        }

        guard let sendResult = try? await sendMessage(message: message, withSecureDns: config.withSecureDns) else {
            return .failure(UserToJournalistMessagingError.failedToSendMessage)
        }

        guard (try? await privateSendingQueue.dequeue(coverMessageFactory: coverMessageFactory)) != nil else {
            return .failure(UserToJournalistMessagingError.failedToDequeue)
        }
        return .success(sendResult.statusCode)
    }

    public func createCoverMessageToCoverNode(coverNodeKeys: [PublicEncryptionKey<CoverNodeMessaging>]) throws
        -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        // create placeholder string instead of inner message
        guard let innerEncryptedPlaceholder = Sodium().randomBytes
            .buf(length: Constants.userToJournalistEncryptedMessageLen) else {
            throw PublicDataRepositoryError.failedToGenerateRandomBytes
        }
        if innerEncryptedPlaceholder.count != Constants.userToJournalistEncryptedMessageLen {
            Debug.println("Output length of innerEncryptedPlaceholder was incorrect")
            throw MultiAnonymousBoxError.badOutputLength
        }

        let coverTrafficRecipientTag = Array(repeating: UInt8(0x00), count: Constants.recipientTagLen)
        // build payload of the outer message (to be read by the CoverNode after decryption)
        let payloadForOuter = coverTrafficRecipientTag + innerEncryptedPlaceholder

        if payloadForOuter.count != Constants.userToCovernodeMessageLen {
            throw MultiAnonymousBoxError.badOutputLength
        }

        // encrypt outer message to CoverNode
        let outerEncryptedMessage = try MultiAnonymousBox<UserToCoverNodeMessageData>.encrypt(
            recipientPks: coverNodeKeys,
            data: payloadForOuter
        )
        return outerEncryptedMessage
    }

    public static func getCoverMessageFactory(verifiedPublicKeys: VerifiedPublicKeys) throws -> CoverMessageFactory {
        let allCoverNodes = verifiedPublicKeys.mostRecentCoverNodeMessagingKeysFromAllHierarchies()
        if allCoverNodes.isEmpty {
            throw PublicDataRepositoryError.failedToGetCoverNodeMessageKeys
        }
        let coverNodeKeys = UserToCoverNodeMessage.selectCoverNodeKeys(coverNodeKeys: allCoverNodes)
        return {
            try PublicDataRepository.shared.createCoverMessageToCoverNode(coverNodeKeys: coverNodeKeys)
        }
    }

    public static func getLatestMessagingKey(recipientId: String) async -> JournalistMessagingPublicKey? {
        guard let publicKeyData = try? await PublicDataRepository.shared.loadAndVerifyPublicKeys() else { return nil }
        let messageKeys = publicKeyData.allMessageKeysForJournalistId(journalistId: recipientId)
        return messageKeys.max { $0.notValidAfter < $1.notValidAfter }
    }

    public static func loadTrustedOrganizationPublicKeys(envType: EnvType,
                                                         now: Date) throws -> [TrustedOrganizationPublicKey] {
        let subpath: EnvType = envType
        let resourcePaths: [String] = Bundle.module.paths(
            forResourcesOfType: "json",
            inDirectory: "organization_keys/\(subpath)/"
        )

        let keys: [TrustedOrganizationPublicKey] = try resourcePaths.compactMap { fullPath in
            // As `Bundle.module.paths` returns the full path, we just want to get the filename
            let fileName = URL(fileURLWithPath: fullPath).lastPathComponent
            let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
            let resourceUrlOption = Bundle.module.url(
                forResource: fileNameWithoutExtension,
                withExtension: ".json",
                subdirectory: "organization_keys/\(subpath)/"
            )
            if let resourceUrl = resourceUrlOption {
                let data = try Data(contentsOf: resourceUrl)
                let keyData = try JSONDecoder().decode(UnverifiedSignedPublicSigningKeyData.self, from: data)

                return SelfSignedPublicSigningKey<TrustedOrganization>.init(
                    key: Sign.KeyPair.PublicKey(keyData.key.bytes),
                    certificate: Signature<TrustedOrganization>.fromBytes(bytes: keyData.certificate.bytes),
                    notValidAfter: keyData.notValidAfter.date, now: now
                )
            }
            return nil
        }

        return keys
    }
}
