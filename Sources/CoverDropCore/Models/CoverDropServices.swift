import Foundation

enum CoverDropServicesError: Error {
    case verifiedPublicKeysNotAvailable
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
           case .prodConfig = appConfig
        {
            if !appConfig.cacheEnabled {
                throw CoverDropServicesError.failedToStartCachingNotEnabledInProd
            }
        }

        // 3. request the public keys and any dead drops
        try await publicDataRepository.pollDataSources()
        // 4. get the verified keys
        guard let verifiedPublicKeys = try? await publicDataRepository.loadAndVerifyPublicKeys() else {
            throw CoverDropServicesError.verifiedPublicKeysNotAvailable
        }
        // 5. generate a coverMessage from the verified Keys
        guard let coverMessageFactory = try? PublicDataRepository.getCoverMessageFactory(verifiedPublicKeys: verifiedPublicKeys) else {
            throw CoverDropServicesError.failedToGenerateCoverMessage
        }
        // 6. create the private sending queue on disk if it does not exist
        try await PrivateSendingQueueRepository.shared.loadOrInitialiseQueue(coverMessageFactory: coverMessageFactory)

        // Check Encrypted Storage exists, and create if not
        _ = try await EncryptedStorage.onAppStart()
        _ = SecretDataRepository.shared

        // Run foreground checks so that there is the same behaviour when app is started,
        // as when its foregrounded
        CoverDropServices.didEnterForeground()

        // Check app resiliance guards
        await SecuritySuite.shared.checkForJailbreak()
        await SecuritySuite.shared.checkForDebuggable()
        await SecuritySuite.shared.checkForPassphrase()
        await SecuritySuite.shared.checkForEmulator()
        await SecuritySuite.shared.checkForReverseEngineering()

        await MainActor.run {
            isReady = publicDataRepository.areKeysAvailable && EncryptedStorage.isReady
        }

        try await CoverDropServiceHelper.addTestStorage()
    }

    public static func getCoverMessageFactoryFromPublicKeysRepository() async throws -> CoverMessageFactory {
        PublicDataRepository.setup(ApplicationConfig.config)

        let publicDataRepository = PublicDataRepository.shared
        guard let verifiedPublicKeys = try? await publicDataRepository.loadAndVerifyPublicKeys() else {
            throw CoverDropServicesError.verifiedPublicKeysNotAvailable
        }
        guard let coverMessageFactory = try? PublicDataRepository.getCoverMessageFactory(verifiedPublicKeys: verifiedPublicKeys) else {
            throw CoverDropServicesError.failedToGenerateCoverMessage
        }
        return coverMessageFactory
    }

    public static func didEnterForeground() {
        Task {
            if let coverMessageFactory = try? await getCoverMessageFactoryFromPublicKeysRepository() {
                try? await PublicDataRepository.shared.dequeueMessageAndSend(coverMessageFactory: coverMessageFactory)
            }
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
