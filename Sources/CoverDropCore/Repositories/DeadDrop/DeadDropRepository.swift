import Foundation

protocol DeadDropRepositoryProtocol {
    func loadDeadDrops(cacheEnabled: Bool) async throws -> DeadDropData?
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

    /// This loads dead drops from the `/users/dead-drops/` endpoint and caches the most recent processed dead drop id
    /// At any point in time, the dead drop api only has the last 2 weeks worth of dead drops, so inital loading will generally have a fixed size.
    func loadDeadDrops(cacheEnabled: Bool = true) async throws -> DeadDropData? {
        let fileUrl = try await DeadDropIdRepository().fileURL()

        // load the last succesfull dead drop ID from disk
        // If this fails, we assume we've never loaded any dead drops before,
        // so we initialise the storage with 0 as the dead drop ID
        // If we are unable to initialise the storage, we just give up.
        guard var latestDeadDropId = try? await DeadDropIdRepository().load() else {
            do {
                try await DeadDropIdRepository().save(deadDrops: DeadDropId(id: 0))
                return try await loadDeadDrops(cacheEnabled: cacheEnabled)
            } catch {
                return nil
            }
        }

        do {
            // if we are outside the cache window, we try and load dead drops from the api
            // using the most recent id + 1

            var shouldRefresh = try FileHelper.isFileOlderThan(durationInSeconds: maxCacheAge, fileUrl: fileUrl, now: now)

            if !cacheEnabled {
                shouldRefresh = true
                latestDeadDropId = DeadDropId(id: 0)
                try await DeadDropIdRepository().save(deadDrops: DeadDropId(id: 0))
            }

            if shouldRefresh || latestDeadDropId.id == 0 {
                let deadDropData = try await DeadDropWebRepository(session: urlSessionData).loadDeadDrops(id: latestDeadDropId.id)
                return deadDropData
            } else {
                // if we are inside the cache window, we do nothing
                return nil
            }
        } catch {
            // if loading the dead drops fails because the API is unavailable we do nothing
            return nil
        }
    }
}
