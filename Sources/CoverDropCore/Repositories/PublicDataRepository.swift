import Foundation

enum PublicDataRepositoryError: Error {
    case configNotAvailable
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
}
