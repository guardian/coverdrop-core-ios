import Foundation
import Sodium

class StatusRepository: CacheableApiRepository<StatusData> {
    init(now: Date = DateFunction.currentTime(), config: CoverDropConfig, urlSession: URLSession) {
        super.init(
            maxCacheAge: TimeInterval(Constants.localCacheDurationBetweenDownloadsSeconds),
            now: now,
            urlSession: urlSession,
            defaultResponse: StatusData(
                status: .unavailable,
                description: "Unavailable",
                timestamp: RFC3339DateTimeString(date: DateFunction.currentTime()),
                isAvailable: false
            ),
            localRepository: StatusLocalRepository(),
            cacheableWebRepository: StatusWebRepository(urlSession: urlSession, baseUrl: config.apiBaseUrl)
        )
    }
}
