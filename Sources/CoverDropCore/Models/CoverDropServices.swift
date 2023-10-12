import CryptoKit
import Foundation

enum CoverDropServicesError: Error {
    case coverNodeKeysNotAvailable
    case failedToGenerateCoverMessage
}

public enum CoverDropServices {
    public static func didLaunch() throws {
        BackgroundTaskService.registerAppRefresh()
    }

    public static func didLaunchAsync() async throws {
        PublicDataRepository.setup(ApplicationConfig.config)
        let publicDataRepository = PublicDataRepository.shared
        _ = SecretDataRepository.shared

        try await publicDataRepository.pollDataSources()

        guard let coverMessage = try? CoverMessage.getCoverMessage() else {
            throw CoverDropServicesError.failedToGenerateCoverMessage
        }

        try await PrivateSendingQueueRepository.shared.start(coverMessage: coverMessage)

        // Check Encrypted Storage exists, and create if not
        _ = try await EncryptedStorage.onAppStart(withSecureEnclave: SecureEnclave.isAvailable)
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
                        .incomingMessage(message: IncomingMessageData(sender: testDefaultJournalist, messageText: "Hey", dateReceived: Date()))
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
            try? await BackgroundLogoutService.logoutIfBackgroundedForTooLong()
            try? await PublicDataRepository.shared.pollDataSources()
            try? await PublicDataRepository.shared.dequeueMessageAndSend()
        }
    }

    public static func didEnterBackground() {
        // This is called when the app is backgrounded
        UserDefaults.standard.set(Date(), forKey: "LastBackgroundDate")
        BackgroundTaskService.scheduleAppRefresh()
    }
}
