import BackgroundTasks
import Combine
import Foundation
import Network

enum CoverDropServicesError: Error {
    case verifiedPublicKeysNotAvailable
    case failedToGenerateCoverMessage
    case failedToStartCachingNotEnabledInProd
    case notInitialized
}

public protocol CoverDropLibraryProtocol {
    var publicDataRepository: PublicDataRepositoryProtocol { get }
    var secretDataRepository: SecretDataRepositoryProtocol { get }
    var config: CoverDropConfig { get }
}

/// The observable implementation used for UI code
public class CoverDropLibrary: CoverDropLibraryProtocol, ObservableObject {
    public var publicDataRepository: PublicDataRepositoryProtocol
    public var secretDataRepository: SecretDataRepositoryProtocol
    public var config: CoverDropConfig

    /// Should only directly referenced in UI code
    @Published public var publishedPublicDataRepository: PublicDataRepository

    /// Should only directly referenced in UI code
    @Published public var publishedSecretDataRepository: SecretDataRepository

    init(
        publicDataRepository: PublicDataRepository,
        secretDataRepository: SecretDataRepository,
        config: CoverDropConfig
    ) {
        self.publicDataRepository = publicDataRepository
        self.secretDataRepository = secretDataRepository
        self.config = config
        publishedPublicDataRepository = publicDataRepository
        publishedSecretDataRepository = secretDataRepository
    }
}

public enum CoverDropServiceState {
    case notInitialized
    case initializing
    case initialized(lib: CoverDropLibrary)
    case failedToInitialize(reason: Error)
}

public class CoverDropService: ObservableObject {
    @Published public var state: CoverDropServiceState = .notInitialized

    private init() {}

    public static var shared = CoverDropService()

    public func didLaunch(config: CoverDropConfig) throws {
        BackgroundTaskService.registerBackgroundSendJob(config: config)

        switch state {
        case .notInitialized:
            state = .initializing
            Task {
                do {
                    let lib = try await didLaunchAsync(config: config)
                    await MainActor.run {
                        state = .initialized(lib: lib)
                        // Run foreground checks so that there is the same behaviour when app is started,
                        // as when its foregrounded, and the app needs to be initialized for this to run.
                        CoverDropService.willEnterForeground(config: config)
                    }
                } catch {
                    await MainActor.run {
                        state = .failedToInitialize(reason: error)
                    }
                }
            }
        case .initialized, .failedToInitialize, .initializing:
            return
        }
    }

    public static func getLibrary() throws -> CoverDropLibrary {
        switch CoverDropService.shared.state {
        case let .initialized(lib: lib):
            return lib
        case let .failedToInitialize(reason: reason):
            throw reason
        case .initializing, .notInitialized:
            throw CoverDropServicesError.notInitialized
        }
    }

    public static func getLibraryBlocking() async throws -> CoverDropLibrary {
        while true {
            switch CoverDropService.shared.state {
            case let .initialized(lib: lib):
                return lib
            case let .failedToInitialize(reason: reason):
                throw reason
            case .initializing, .notInitialized:
                try await Task.sleep(nanoseconds: UInt64(0.1))
            }
        }
    }

    private func didLaunchAsync(config: CoverDropConfig) async throws -> CoverDropLibrary {
        // Setup the public data repository
        let urlSession = getUrlSession(config: config)
        let publicDataRepository = PublicDataRepository(config, urlSession: urlSession)

        // Note the app will not be made available if the cache is not enabled in production
        if case config.envType = .prod {
            if !config.cacheEnabled {
                throw CoverDropServicesError.failedToStartCachingNotEnabledInProd
            }
        }

        //  request the public keys and any dead drops
        try await publicDataRepository.pollPublicKeysAndStatusApis()
        //  get the verified keys
        guard (try? await publicDataRepository.loadAndVerifyPublicKeys()) != nil else {
            throw CoverDropServicesError.verifiedPublicKeysNotAvailable
        }

        // 5. generate a coverMessage from the verified Keys
        guard let coverMessageFactory = try? publicDataRepository.getCoverMessageFactory() else {
            throw CoverDropServicesError.failedToGenerateCoverMessage
        }
        // 6. create the private sending queue on disk if it does not exist
        _ = try await PrivateSendingQueueRepository.shared.loadOrInitialiseQueue(coverMessageFactory)

        // Check Encrypted Storage exists, and create if not
        _ = try await EncryptedStorage.onAppStart(config: config)

        let secretDataRepository = SecretDataRepository(publicDataRepository: publicDataRepository)

        // Check app resiliance guards
        await SecuritySuite.shared.checkForJailbreak()
        await SecuritySuite.shared.checkForDebuggable()
        await SecuritySuite.shared.checkForPassphrase()
        await SecuritySuite.shared.checkForEmulator()
        await SecuritySuite.shared.checkForReverseEngineering()

        // We load the dead drops after the service is marked ready
        // so we do not delay startup
        _ = try? await publicDataRepository.loadDeadDrops()

        // Handle all modifications that might need to happen as a result of passed in test flags
        try await CoverDropServiceHelper.handleTestingFlags(
            config: config,
            verifiedKeys: publicDataRepository.getVerifiedKeys()
        )

        return CoverDropLibrary(
            publicDataRepository: publicDataRepository,
            secretDataRepository: secretDataRepository,
            config: config
        )
    }

    private func getUrlSession(config: CoverDropConfig) -> URLSession {
        let urlSession = URLSessionConfiguration.ephemeral

        // We support secure DNS via cloudflare by default,
        // but this can be disabled by the integrating app if required.
        if config.withSecureDns {
            let secureDNS = SecureDNSConfig.cloudflare
            NWParameters.PrivacyContext.default.requireEncryptedNameResolution(
                true,
                fallbackResolver: .https(secureDNS.httpsURL, serverAddresses: secureDNS.serverAddresses)
            )
            if #available(iOS 16.0, *) {
                urlSession.requiresDNSSECValidation = true
            }
        }

        // employ mocked url protocol for UI and integration tests
        if TestingBridge.isMockedDataEnabled() {
            URLProtocolMock.mockURLs = MockUrlData.getMockUrlData()
            urlSession.protocolClasses = [URLProtocolMock.self]
        }

        return URLSession(configuration: urlSession)
    }

    public static func willEnterForeground(config: CoverDropConfig) {
        Task {
            if case let .initialized(repositories) = CoverDropService.shared.state {
                async let logout: () = BackgroundLogoutService.logoutIfBackgroundedForTooLong()
                // Run background task for message sending, this is done on app foreground
                async let messageSending: () = try await BackgroundMessageScheduleService
                    .onAppForeground(publicDataRepository: repositories.publicDataRepository, config: config)
                async let publicKeysAndStatus: () = repositories.publicDataRepository
                    .pollPublicKeysAndStatusApis()
                async let deadDrops = repositories.publicDataRepository.loadDeadDrops()

                try? await logout
                try? await messageSending
                try? await publicKeysAndStatus
                _ = try? await deadDrops
            }
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
