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
        _ = try await EncryptedStorage.onAppStart()
        _ = SecretDataRepository.shared

        await MainActor.run {
            isReady = publicDataRepository.areKeysAvailable && EncryptedStorage.isReady && privateSendingQueueIsReady
        }

        try await CoverDropServiceHelper.addTestStorage()
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
