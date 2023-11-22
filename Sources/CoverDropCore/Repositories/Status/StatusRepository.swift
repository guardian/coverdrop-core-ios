import Foundation
import Sodium

class StatusRepository: CacheableApiRepository<StatusData> {
    public init(now: Date = Date(), urlSessionConfig: URLSession = ApplicationConfig.config.urlSessionConfig()) {
        super.init(
            maxCacheAge: TimeInterval(Constants.localCacheDurationBetweenDownloadsSeconds),
            now: now,
            urlSessionConfig: urlSessionConfig,
            defaultResponse: StatusData(status: .unavailable, description: "Unavailable", timestamp: RFC3339DateTimeString(date: Date()), isAvailable: false),
            localRepository: StatusLocalRepository(),
            cacheableWebRepository: StatusWebRepository(session: urlSessionConfig
            )
        )
    }
}
