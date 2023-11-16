import Foundation
import Sodium

public class StatusRepository: ObservableObject {
    // 24 hours in seconds
    let maxCacheAge = Double(60 * 60 * 24)

    public init(now: Date = Date(), urlSessionConfig: URLSession = ApplicationConfig.config.urlSessionConfig()) {
        self.now = now
        self.urlSessionConfig = urlSessionConfig
    }

    public let now: Date
    public let urlSessionConfig: URLSession

    public func getStatusWithCache(cacheEnabled: Bool = true) async throws -> StatusData {
        let defaultStatus = StatusData(status: .unavailable, description: "Unavailable", timestamp: RFC3339DateTimeString(date: Date()), isAvailable: false)
        if cacheEnabled {
            var cachedStatus = defaultStatus

            let fileUrl = try await StatusLocalRepository().fileURL()
            let cacheFileAlreadyExists = FileManager.default.fileExists(atPath: fileUrl.path)

            // This should only run on first ever load
            if !cacheFileAlreadyExists {
                do {
                    let statusData = try await StatusWebRepository(session: urlSessionConfig).loadStatus()
                    try await StatusLocalRepository().save(status: statusData)
                    return statusData
                } catch {
                    return cachedStatus
                }
            }
            // If the cache file does not exist we initialise the cache with empty cache data
            if let gotCachedStatus = try? await StatusLocalRepository().load() {
                cachedStatus = gotCachedStatus
            }

            // If we outside the cache time, we want to get new data from the api and save
            // the merged and trimmed results back to the cache file
            if (try? FileHelper.isFileOlderThan(durationInSeconds: maxCacheAge, fileUrl: fileUrl, now: now) == true) != nil
            {
                if let statusData = try? await StatusWebRepository(session: urlSessionConfig).loadStatus() {
                    try? await StatusLocalRepository().save(status: statusData)
                    return statusData
                } else {
                    return cachedStatus
                }
            } else {
                // otherwise we just return the cached deaddrops
                return cachedStatus
            }
        } else {
            if let statusData = try? await StatusWebRepository(session: urlSessionConfig).loadStatus() {
                return statusData
            }
        }
        return defaultStatus
    }
}
