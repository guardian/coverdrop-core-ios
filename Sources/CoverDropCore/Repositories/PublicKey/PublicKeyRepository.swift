import Foundation

protocol PublicKeyRepositoryProtocol {
    func loadKeys(cacheEnabled: Bool) async throws -> PublicKeysData
}

/// This repository is for managing public keys published by the Private Key Infrastructure
/// This repository tries to load the keys data from disk, if this fails it will then try and reload the data from the web api
/// and store the results to file before returning them

public struct PublicKeyRepository: PublicKeyRepositoryProtocol {
    // 24 hours in seconds
    let maxCacheAge = Double(60 * 60 * 24)

    init(now: Date = Date(), urlSessionConfig: URLSession = ApplicationConfig.config.urlSessionConfig()) {
        self.now = now
        self.urlSessionConfig = urlSessionConfig
    }

    public let now: Date
    public let urlSessionConfig: URLSession

    /// This function is responsible for loading the public keys from the API, or a cache version of that reponse
    /// 1. The keys are allowed to be cached on disk for the duration  speficied in `canRefresh`
    /// 2. If the local cache is older than `MAX_CACHE_AGE`, we try to get the keys data from the API.
    /// 3. If we are inside the cache duration, we load the keys data from disk
    /// 4. If we were not supposed to refresh the keys, but loading from disk failed OR
    /// If the API call fails for some reason we try the api again
    /// 5. If the API call failed, we try to load from disk as a last resort

    public func loadKeys(cacheEnabled: Bool = true) async throws -> PublicKeysData {
        let fileUrl = try await PublicKeyLocalRepository().fileURL()
        if !cacheEnabled {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: fileUrl.path) {
                try fileManager.removeItem(atPath: fileUrl.path)
            }
        }

        do {
            let shouldRefresh = try FileHelper.isFileOlderThan(durationInSeconds: maxCacheAge, fileUrl: fileUrl, now: now)
            if shouldRefresh {
                return try await loadFromApiAndCacheResults()
            } else {
                return try await loadFromFile()
            }
        } catch {
            do {
                return try await loadFromApiAndCacheResults()
            } catch {
                return try await loadFromFile()
            }
        }
    }

    private func loadFromFile() async throws -> PublicKeysData {
        let keys = try await PublicKeyLocalRepository().load()
        return keys
    }

    private func loadFromApiAndCacheResults() async throws -> PublicKeysData {
        // if we cannot load from disk, read from the web, and then store to disk
        let data = try await PublicKeyWebRepository(session: urlSessionConfig, baseUrl: ApplicationConfig.config.apiBaseUrl).loadKeys()
        try await PublicKeyLocalRepository().save(publicKeys: data)
        return data
    }
}
