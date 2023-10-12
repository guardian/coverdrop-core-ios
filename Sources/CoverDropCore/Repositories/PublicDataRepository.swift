import Foundation
import Sodium

enum PublicDataRepositoryError: Error {
    case configNotAvailable
    case failedToGenerateRandomBytes
}

public class PublicDataRepository: ObservableObject {
    @Published public var verifiedPublicKeysData: VerifiedPublicKeys?
    @Published public var deadDrops: VerifiedDeadDrops?
    @Published public var areKeysAvailable: Bool = false
    @Published public var cacheEnabled: Bool = true
    public private(set) static var appConfig: ConfigType?

    public class func setup(_ config: ConfigType) {
        PublicDataRepository.appConfig = config
    }

    public static let shared = PublicDataRepository()

    private init() {
        guard let config = PublicDataRepository.appConfig else {
            fatalError("Error - you must call setup before accessing PublicDataRepository.shared")
        }
        Task {
            try await pollDataSources()
        }
    }

    // This is @MainActor is done as timers are required to be run on the main UI thread.
    // We do all actual work in a background Task, so this will not affect UI rendering performance.
    @MainActor public func pollDataSources() async throws {
        try await loadPublicKeys()
        try await loadDeadDrops()
    }

    public func loadDeadDrops() async throws {
        guard let cacheEnabled = PublicDataRepository.appConfig?.cacheEnabled else {
            throw PublicDataRepositoryError.configNotAvailable
        }

        // Load dead drops from journalists
        if let deadDrops = try await DeadDropRepository().loadDeadDrops(cacheEnabled: cacheEnabled),
           let verifiedPublicKeys = verifiedPublicKeysData
        {
            let verifiedDeadDropData = VerifiedDeadDrops.fromAllDeadDropData(deadDrops: deadDrops, verifiedKeys: verifiedPublicKeys)

            self.deadDrops = verifiedDeadDropData
        }
    }

    /// This loads and verifies the public key and dead drops from the API.
    /// Once verified, they are added to the `publicData` thus available throughtout the app.
    /// Public keys and dead drops can be updated at any time in the API, so we poll to stay up to date.
    @MainActor func loadPublicKeys() async throws {
        guard let cacheEnabled = PublicDataRepository.appConfig?.cacheEnabled else {
            throw PublicDataRepositoryError.configNotAvailable
        }
        // Load public keys
        do {
            if let config = PublicDataRepository.appConfig {
                let publicKeysData = try await PublicKeyRepository().loadKeys(cacheEnabled: cacheEnabled)
                let trustedRootKeys = try config.organizationPublicKeys()
                let dateFunction = config.currentKeysPublishedTime()
                let verifiedPublicKeysData = try VerifiedPublicKeys(publicKeysData: publicKeysData, trustedOrganizationPublicKeys: trustedRootKeys, currentTime: dateFunction)
                self.verifiedPublicKeysData = verifiedPublicKeysData
                areKeysAvailable = true
            }
        } catch {}
    }

    public func sendMessage(message: MultiAnonymousBox<UserToCoverNodeMessageData>) async throws {
        if let data = message.asBytes().base64Encode() {
            let jsonData: Data = try JSONEncoder().encode(data)
            guard let postResponse = try? await UserToJournalistMessageWebRepository().sendMessage(jsonData: jsonData) else {
                throw UserToJournalistMessagingError.failedToSendMessage
            }
        } else {
            throw UserToJournalistMessagingError.unableToBase64Encode
        }
    }

    /// This dequeues a message from the `PrivateSendingQueue` and sends it to the user to journalist
    /// message api
    /// 1. dequeue message from privateSendingQueue
    /// 2. send to the api
    public func dequeueMessageAndSend(privateSendingQueue: PrivateSendingQueueRepository = PrivateSendingQueueRepository.shared) async throws {
        if let message = try? await privateSendingQueue.peek(),
           let allCoverNodes = try? verifiedPublicKeysData?.mostRecentCoverNodeMessagingKeysFromAllHierarchies()
        {
            if let messageResult = try? await sendMessage(message: message) {
                let coverNodeKeys = UserToCoverNodeMessage.selectCovernodeKeys(coverNodeKeys: allCoverNodes)
                if let coverMessage = try? createCoverMessageToCoverNode(coverNodeKeys: coverNodeKeys) {
                    guard let dequeueResult = try? await privateSendingQueue.dequeue(coverMessage: coverMessage) else {
                        throw UserToJournalistMessagingError.failedToDequeue
                    }
                }
            } else {
                throw UserToJournalistMessagingError.failedToSendMessage
            }
        } else {
            throw UserToJournalistMessagingError.failedToPeekMessage
        }
    }

    public func createCoverMessageToCoverNode(coverNodeKeys: [PublicEncryptionKey<CoverNodeMessaging>]) throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        // create placeholder string instead of inner message
        guard let innerEncryptedPlaceholder = Sodium().randomBytes.buf(length: Constants.userToJournalistEncryptedMessageLen) else {
            throw PublicDataRepositoryError.failedToGenerateRandomBytes
        }
        precondition(innerEncryptedPlaceholder.count == Constants.userToJournalistEncryptedMessageLen)

        let coverTrafficRecipientTag = Array(repeating: UInt8(0x00), count: Constants.recipientTagLen)
        // build payload of the outer message (to be read by the CoverNode after decryption)
        let payloadForOuter = coverTrafficRecipientTag + innerEncryptedPlaceholder

        precondition(payloadForOuter.count == Constants.userToCovernodeMessageLen)

        // encrypt outer message to CoverNode
        let outerEncryptedMessage = try MultiAnonymousBox<UserToCoverNodeMessageData>.encrypt(recipientPks: coverNodeKeys, data: payloadForOuter)
        return outerEncryptedMessage
    }
}
