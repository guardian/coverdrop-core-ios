import BackgroundTasks
import Foundation
import Network

enum CoverDropServicesError: Error {
    case verifiedPublicKeysNotAvailable
    case failedToGenerateCoverMessage
    case failedToStartCachingNotEnabledInProd
}

public class CoverDropServices: ObservableObject {
    @MainActor @Published public var isReady: Bool = false

    private init() {}

    public static var shared = CoverDropServices()

    public func didLaunch(config: CoverDropConfig) throws {
        BackgroundTaskService.registerBackgroundSendJob(config: config)
        // We support secure DNS via cloudflare by default,
        // but this can be disabled by the integrating app if required.
        if config.withSecureDns {
            let secureDNS = SecureDNSConfig.cloudflare
            NWParameters.PrivacyContext.default.requireEncryptedNameResolution(
                true,
                fallbackResolver: .https(secureDNS.httpsURL, serverAddresses: secureDNS.serverAddresses)
            )
        }
        Task {
            try? await didLaunchAsync(config: config)
        }
    }

    private func didLaunchAsync(config: CoverDropConfig) async throws {
        // To initialise the CoverDrop service we need to:
        // 1. Setup the public data repository
        PublicDataRepository.setup(config)
        // 2. Get the shared instance of public data repository
        let publicDataRepository = PublicDataRepository.shared

        // Note the app will not be made available if the cache is not enabled in production
        if let appConfig = PublicDataRepository.appConfig,
           case appConfig.envType = .prod {
            if !appConfig.cacheEnabled {
                throw CoverDropServicesError.failedToStartCachingNotEnabledInProd
            }
        }

        // 3. request the public keys and any dead drops
        try await publicDataRepository.pollPublicKeysAndStatusApis(config: config)
        // 4. get the verified keys
        guard let verifiedPublicKeys = try? await publicDataRepository.loadAndVerifyPublicKeys(config: config) else {
            throw CoverDropServicesError.verifiedPublicKeysNotAvailable
        }

        // 5. generate a coverMessage from the verified Keys
        guard let coverMessageFactory = try? PublicDataRepository
            .getCoverMessageFactory(
                verifiedPublicKeys: verifiedPublicKeys
            ) else {
            throw CoverDropServicesError.failedToGenerateCoverMessage
        }
        // 6. create the private sending queue on disk if it does not exist
        _ = try await PrivateSendingQueueRepository.shared
            .loadOrInitialiseQueue(coverMessageFactory: coverMessageFactory)

        // Check Encrypted Storage exists, and create if not
        _ = try await EncryptedStorage.onAppStart(config: config)
        _ = SecretDataRepository.shared

        // Run background task for message sending, this is only done on App startup
        _ = await BackgroundMessageScheduleService.onAppStart(verifiedPublicKeys: verifiedPublicKeys, config: config)

        // Run foreground checks so that there is the same behaviour when app is started,
        // as when its foregrounded
        CoverDropServices.willEnterForeground(config: config)

        // Check app resiliance guards
        await SecuritySuite.shared.checkForJailbreak()
        await SecuritySuite.shared.checkForDebuggable()
        await SecuritySuite.shared.checkForPassphrase()
        await SecuritySuite.shared.checkForEmulator()
        await SecuritySuite.shared.checkForReverseEngineering()

        await MainActor.run {
            isReady = publicDataRepository.areKeysAvailable && EncryptedStorage.isReady
        }

        // We load the dead drops after the service is marked ready
        // so we do not delay startup
        _ = try? await PublicDataRepository.loadDeadDrops(verifiedPublicKeys: verifiedPublicKeys)
        #if DEBUG
            await CoverDropServiceHelper.removeBackgroundSendState(config: config)
        #endif

        try await CoverDropServiceHelper.addTestStorage(config: config)
    }

    public static func getCoverMessageFactoryFromPublicKeysRepository(
        verifiedPublicKeys: VerifiedPublicKeys
    ) throws
        -> CoverMessageFactory {
        guard let coverMessageFactory = try? PublicDataRepository
            .getCoverMessageFactory(
                verifiedPublicKeys: verifiedPublicKeys
            ) else {
            throw CoverDropServicesError.failedToGenerateCoverMessage
        }
        return coverMessageFactory
    }

    public static func willEnterForeground(config: CoverDropConfig) {
        Task {
            PublicDataRepository.setup(config)
            async let logout: () = BackgroundLogoutService.logoutIfBackgroundedForTooLong()
            async let publicKeysAndStatus: () = PublicDataRepository.shared.pollPublicKeysAndStatusApis(config: config)
            async let deadDrops = PublicDataRepository.loadDeadDrops(
                verifiedPublicKeys: PublicDataRepository.shared.loadAndVerifyPublicKeys(config: config)
            )

            try? await logout
            try? await publicKeysAndStatus
            _ = try? await deadDrops
        }
    }

    public static func didEnterBackground() {
        // This is called when the app enters the background
        UserDefaults.standard.set(Date(), forKey: "LastBackgroundDate")
        do {
            let fileURL = try EncryptedStorage.secureStorageFileURL()
            try EncryptedStorage.touchExistingStorage(fileUrl: fileURL)
        } catch {
            Debug.println("Failed to touch storage on close")
        }

        // This puts the setting up of background traffic sending into a async task
        // This could fail if the task does not complete within 5 seconds
        // https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationdidenterbackground(_:)
        // as its called from applicationDidEnterBackground
        // In most scenarios the user should aready have the verifiedPublicKeys, so we are just loading from cache
        // But if they don't it will required a http round trip.
        // If this doesn't complete in time, we won't schedule a background task, but this will get picked up
        // by the BackgroundMessageScheduleService.onAppStart cleanup function

        Task { await BackgroundMessageScheduleService.onEnterBackground() }
    }
}
