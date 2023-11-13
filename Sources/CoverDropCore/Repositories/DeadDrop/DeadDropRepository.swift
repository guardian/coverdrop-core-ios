import Foundation

protocol DeadDropRepositoryProtocol {
    func loadDeadDropsWithCache(cacheEnabled: Bool) async throws -> DeadDropData?
}

/// This repository is for managing dead drops published from the API `/users/dead-drops`
/// 1. This repository tries to load the last succesfull dead drop ID from disk, if this fails it will then try and get dead drops from id 0
///

struct DeadDropRepository: DeadDropRepositoryProtocol {
    // One hour in seconds
    let maxCacheAge = Double(60 * 60)

    init(now: Date = Date(), urlSession: URLSession = ApplicationConfig.config.urlSessionConfig()) {
        self.now = now
        urlSessionData = urlSession
    }

    public let now: Date
    public let urlSessionData: URLSession

    /// This loads dead drops from the `/user/dead-drops/` endpoint and caches the response.
    /// Each dead drop will only be kept in cache for 2 weeks, and will be removed during a merge and trim operation, once the dead drop `createdAt` date  falls outside that period.
    /// A merge and trim only happens when new dead drops have been got from the api.
    /// At any point in time, the dead drop api only has the last 2 weeks worth of dead drops, so inital loading will generally have a fixed size.
    func loadDeadDropsWithCache(cacheEnabled: Bool = true) async throws -> DeadDropData? {
        var latestDeadDropId = 0

        if cacheEnabled {
            var cachedDeadDrops = DeadDropData(deadDrops: [])

            let fileUrl = try await DeadDropLocalRepository().fileURL()
            let cacheFileAlreadyExists = FileManager.default.fileExists(atPath: fileUrl.path)

            // This should only run on first ever load
            if !cacheFileAlreadyExists {
                do {
                    let deadDropData = try await DeadDropWebRepository(session: urlSessionData).loadDeadDrops(id: latestDeadDropId)
                    try await DeadDropLocalRepository().save(deadDrops: deadDropData)
                    return deadDropData
                } catch {
                    return cachedDeadDrops
                }
            }
            // If the cache file does not exist we initialise the cache with empty dead drop data
            // get the highest id that is stored in the cache
            if let gotCachedDeadDrops = try? await DeadDropLocalRepository().load(),
               let highestLocalDeadDropId: Int = gotCachedDeadDrops.deadDrops.max(by: { $0.id < $1.id })?.id
            {
                latestDeadDropId = highestLocalDeadDropId
                cachedDeadDrops = gotCachedDeadDrops
            }

            // If we outside the cache time, we want to get new data from the api and save
            // the merged and trimmed results back to the cache file
            if (try? FileHelper.isFileOlderThan(durationInSeconds: maxCacheAge, fileUrl: fileUrl, now: now) == true) != nil
            {
                if let deadDropData = try? await DeadDropWebRepository(session: urlSessionData).loadDeadDrops(id: latestDeadDropId) {
                    let mergedDeadDrops = await DeadDropLocalRepository().mergeAndTrim(existingDeadDrops: cachedDeadDrops, newDeadDrops: deadDropData)
                    try? await DeadDropLocalRepository().save(deadDrops: mergedDeadDrops)
                    return mergedDeadDrops
                }
            } else {
                // otherwise we just return the cached deaddrops
                return cachedDeadDrops
            }
        } else {
            if let deadDropData = try? await DeadDropWebRepository(session: urlSessionData).loadDeadDrops(id: latestDeadDropId) {
                return deadDropData
            }
        }
        return nil
    }
}
