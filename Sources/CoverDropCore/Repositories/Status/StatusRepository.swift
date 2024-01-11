import Foundation
import Sodium

class StatusRepository: CacheableApiRepository<StatusData> {
    init(now: Date = Date(), config: ConfigType, urlSessionConfig: URLSession) {
        super.init(
            maxCacheAge: TimeInterval(Constants.localCacheDurationBetweenDownloadsSeconds),
            now: now,
            urlSessionConfig: urlSessionConfig,
            defaultResponse: StatusData(status: .unavailable, description: "Unavailable", timestamp: RFC3339DateTimeString(date: Date()), isAvailable: false),
            localRepository: StatusLocalRepository(),
            cacheableWebRepository: StatusWebRepository(session: urlSessionConfig, baseUrl: config.apiBaseUrl)
        )
    }
}
