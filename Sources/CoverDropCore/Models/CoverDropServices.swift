import CryptoKit
import Foundation

enum CoverDropServicesError: Error {
    case coverNodeKeysNotAvailable
    case failedToGenerateCoverMessage
    case failedToStartCachingNotEnabledInProd
}

public class CoverDropServices: ObservableObject {
    @MainActor @Published public var isReady: Bool = false

    private init() {}

    public static var shared = CoverDropServices()

    public func didLaunch() throws {
        BackgroundTaskService.registerAppRefresh()
    }

    public func didLaunchAsync() async throws {
        // To initialise the CoverDrop service we need to:
        // 1. Setup the public data repository
        PublicDataRepository.setup(ApplicationConfig.config)
        // 2. Get the shared instance of public data repository
        let publicDataRepository = PublicDataRepository.shared

        // Note the app will not be made available if the cache is not enabled in production
        if let appConfig = PublicDataRepository.appConfig,
           case .prodConfig = appConfig {
            if !appConfig.cacheEnabled {
                throw CoverDropServicesError.failedToStartCachingNotEnabledInProd
            }
        }

        // 3. request the public keys and any dead drops
        try await publicDataRepository.pollDataSources()
        // 4. get the verified keys
        guard let verifiedPublicKeys = publicDataRepository.verifiedPublicKeysData else {
            throw CoverDropServicesError.coverNodeKeysNotAvailable
        }
        // 5. generate a coverMessage from the verified Keys
        guard let coverMessageFactory = try? PublicDataRepository.getCoverMessageFactory(verifiedPublicKeys: verifiedPublicKeys) else {
            throw CoverDropServicesError.failedToGenerateCoverMessage
        }
        // 6. starte the private sending queue
        try await PrivateSendingQueueRepository.shared.start(coverMessageFactory: coverMessageFactory)
        let privateSendingQueueIsReady = await PrivateSendingQueueRepository.shared.isReady

        // Check Encrypted Storage exists, and create if not
        _ = try await EncryptedStorage.onAppStart(withSecureEnclave: SecureEnclave.isAvailable)
        _ = SecretDataRepository.shared

        await MainActor.run {
            isReady = publicDataRepository.areKeysAvailable && EncryptedStorage.isReady && privateSendingQueueIsReady
        }

        if ApplicationConfig.config.startWithTestStorage {
            // If we are in UI_TEST_MODE, we want to initialise the storage with a known passphase
            // and set of user keys, so we can work with UI
            let passphrase = ValidPassword(password: "external jersey squeeze luckiness")
            let userSecretMessageKey = try PublicKeysHelper.shared.getTestUserMessageSecretKey()
            let userPublicMessageKey = try PublicKeysHelper.shared.getTestUserMessagePublicKey()
            let userKeyPair = EncryptionKeypair(publicKey: userPublicMessageKey, secretKey: userSecretMessageKey)

            let storage = try await EncryptedStorage.createNewStorageWithPassphrase(passphrase: passphrase, withSecureEnclave: SecureEnclave.isAvailable, userKeyPair: userKeyPair)

            if ApplicationConfig.config.startWithTestMessages {
                if let testDefaultJournalist = PublicKeysHelper.shared.testDefaultJournalist {
                    let messages: [Message] = await [
                        .outboundMessage(message: OutboundMessageData(recipient: testDefaultJournalist, messageText: "Hey", dateSent: Date())),
                        .incomingMessage(message: .textMessage(message: IncomingMessageData(sender: testDefaultJournalist, messageText: "Hey", dateReceived: Date())))
                    ]
                    let newStateWithMessages = await UnlockedSecretData(passphrase: passphrase, messageMailbox: messages, userKey: userKeyPair, privateSendingQueueSecret: storage.privateSendingQueueSecret)
                    let key = try await SecureEnclavePrivateKey.loadKey(name: EncryptedStorage.fileName)
                    try await EncryptedStorage.updateStorageOnDisk(storage: storage, passphrase: passphrase, newState: newStateWithMessages, withSecureEnclave: SecureEnclave.isAvailable, secureEnclaveKey: key)
                }
            }
        }
    }

    public static func didEnterForeground() {
        Task {
            try? await PublicDataRepository.shared.dequeueMessageAndSend()
            try? await BackgroundLogoutService.logoutIfBackgroundedForTooLong()
            try? await PublicDataRepository.shared.pollDataSources()
        }
    }

    public static func didEnterBackground() {
        // This is called when the app is backgrounded
        UserDefaults.standard.set(Date(), forKey: "LastBackgroundDate")
        BackgroundTaskService.scheduleAppRefresh()
    }
}
