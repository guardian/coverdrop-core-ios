import Foundation

/// This repository is for managing dead drops published from the API `/users/dead-drops`
/// 1. This repository tries to load the last succesfull dead drop ID from disk, if this fails it will then try and get
/// dead drops from id 0
///

class DeadDropRepository: CacheableApiRepository<DeadDropData> {
    init(now: Date = Date(), config: CoverDropConfig, urlSession: URLSession) {
        super.init(
            maxCacheAge: TimeInterval(Constants.localCacheDurationBetweenDownloadsSeconds),
            now: now,
            urlSession: urlSession,
            defaultResponse: DeadDropData(deadDrops: []),
            localRepository: DeadDropLocalRepository(),
            cacheableWebRepository: DeadDropWebRepository(urlSession: urlSession, baseUrl: config.apiBaseUrl)
        )
    }

    /// This loads dead drops from the `/user/dead-drops/` endpoint and caches the response.
    /// Each dead drop will only be kept in cache for 2 weeks, and will be removed during a merge and trim operation,
    /// once the dead drop `createdAt` date  falls outside that period.
    /// A merge and trim only happens when new dead drops have been got from the api.
    /// At any point in time, the dead drop api only has the last 2 weeks worth of dead drops, so inital loading will
    /// generally have a fixed size.

    override func getFromApiAndCache() async -> DeadDropData? {
        do {
            var availableCachedData: DeadDropData = .init(deadDrops: [])

            if let localCachedData = try? await localRepository.load() {
                availableCachedData = localCachedData
            }

            let highestCachedDeadDropId = availableCachedData.deadDrops.max(by: { $0.id < $1.id })?.id ?? 0
            let params = ["ids_greater_than": String(highestCachedDeadDropId)]
            let webData: DeadDropData = try await cacheableWebRepository.get(params: params)

            let mergedDeadDrops = await DeadDropLocalRepository().mergeAndTrim(
                existingDeadDrops: availableCachedData,
                newDeadDrops: webData
            )

            try await localRepository.save(data: mergedDeadDrops)
            return mergedDeadDrops
        } catch {
            return defaultResponse
        }
    }

    override func getFromApiOnly() async -> DeadDropData? {
        let params = ["ids_greater_than": "0"]
        if let webData: DeadDropData = try? await cacheableWebRepository.get(params: params) {
            return webData
        } else {
            return nil
        }
    }
}
