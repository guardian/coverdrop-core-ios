@testable import CoverDropCore
import Sodium
import XCTest

final class DeadDropRepositoryTests: XCTestCase {
    func removeDeadDropCacheFile() async throws {
        let fileManager = FileManager.default
        let fileURL = try await DeadDropLocalRepository().fileURL()

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(atPath: fileURL.path)
        }
    }

    func fakeUserFacingDeadDrop(id: Int, createdAt: Date) -> DeadDrop {
        let emptyMessage = Base64EncodedString(bytes: "this is a test message".asBytes())
        let emptyCert = HexEncodedString(bytes: "68cce4ab0dc9e071f497ce8d37ec01265bf283f5f2a0038f3861bc78a18d16287ec0172b23dbe808c56101810e363c51260c8cf7fda5d634e5c627f80c8b5e08".asBytes())
        return DeadDrop(id: id, createdAt: RFC3339DateTimeString(date: createdAt), data: emptyMessage, cert: emptyCert)
    }

    func testFirstRunDoesNotCacheIfAPIResponseFailedAndCacheEnabled() async throws {
        try await removeDeadDropCacheFile()

        let urlSessionConfig = mockApiResponseFailure()

        let results = try await DeadDropRepository(urlSession: urlSessionConfig).loadDeadDropsWithCache(cacheEnabled: true)

        XCTAssertNotNil(results)
        XCTAssertTrue(results!.deadDrops.isEmpty)
    }

    func testFirstRunDoesNotCacheIfAPIResponseFailedAndCacheDisabled() async throws {
        try await removeDeadDropCacheFile()

        let urlSessionConfig = mockApiResponseFailure()

        let results = try await DeadDropRepository(urlSession: urlSessionConfig).loadDeadDropsWithCache(cacheEnabled: false)

        XCTAssertNil(results)
    }

    func testFirstRunWithOutsideCacheWindowApiResponseLoadsDeadDropsAndCacheDisabled() async throws {
        try await removeDeadDropCacheFile()

        let urlSessionConfig = mockApiResponse()

        // note we are outside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 48), urlSession: urlSessionConfig).loadDeadDropsWithCache(cacheEnabled: false)

        if let validResults = results {
            XCTAssertFalse(validResults.deadDrops.isEmpty)
        } else {
            XCTFail("Failed to get result")
        }
    }

    func testFirstRunWithOutsideCacheWindowApiResponseLoadsDeadDrops() async throws {
        try await removeDeadDropCacheFile()

        let urlSessionConfig = mockApiResponse()

        // note we are outside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 48), urlSession: urlSessionConfig).loadDeadDropsWithCache()

        if let validResults = results {
            XCTAssertFalse(validResults.deadDrops.isEmpty)
        } else {
            XCTFail("Failed to get result")
        }
    }

    func testFirstRunInsideCacheWindowWithApiResponseLoadsDeadDropsAndCachesResponse() async throws {
        try await removeDeadDropCacheFile()

        let urlSessionConfig = mockApiResponse()
        // note we are intside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 50), urlSession: urlSessionConfig).loadDeadDropsWithCache()
        let cache = try await DeadDropLocalRepository().load()
        XCTAssertEqual(results?.deadDrops, cache.deadDrops)
    }

    func testFutureRunOutsideCacheWindowWithApiResponseLoadsDeadDropsButNotUpdateId() async throws {
        try await removeDeadDropCacheFile()

        let urlSessionConfig = mockApiResponse()
        // note we are outside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 2), urlSession: urlSessionConfig).loadDeadDropsWithCache()
        let cache = try await DeadDropLocalRepository().load()
        XCTAssertEqual(results?.deadDrops, cache.deadDrops)
    }

    func testFutureRunInsideCacheWindowWithFailedApiResponse() async throws {
        try await removeDeadDropCacheFile()
        let urlSessionConfig = mockApiResponseFailure()

        // note we are inside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 50), urlSession: urlSessionConfig).loadDeadDropsWithCache(cacheEnabled: false)

        XCTAssertTrue(results == nil)
    }

    func testCacheInsideCacheWindowUpdatesCache() async throws {
        try await removeDeadDropCacheFile()
        let urlSessionConfig = mockApiResponse()

        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 90), urlSession: urlSessionConfig).loadDeadDropsWithCache()
        let results2 = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 90), urlSession: urlSessionConfig).loadDeadDropsWithCache()

        XCTAssertEqual(results?.deadDrops, results2?.deadDrops)
    }

    func testCacheInsideCacheWindowReturnsCachedResults() async throws {
        try await removeDeadDropCacheFile()
        let urlSessionConfig = mockApiResponse()

        guard let deadDropDate = try? PublicKeysHelper.readLocalGeneratedAtFile() else {
            XCTFail("Failed to get deadDrop loaded date")
            return
        }
        // both requests are outside the cache window, so we should be populating the cache
        // on the first request, and reading on the second request
        let deadDropApril01 = fakeUserFacingDeadDrop(id: 10, createdAt: deadDropDate)
        let deadDropApril05 = fakeUserFacingDeadDrop(id: 18, createdAt: deadDropDate)
        let deadDropApril06 = fakeUserFacingDeadDrop(id: 19, createdAt: deadDropDate)

        let cached = DeadDropData(deadDrops: [deadDropApril01, deadDropApril05, deadDropApril06])

        try await DeadDropLocalRepository().save(deadDrops: cached)

        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 40), urlSession: urlSessionConfig).loadDeadDropsWithCache()
        XCTAssertTrue(results?.deadDrops.count == 4)

        let results2 = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 90), urlSession: urlSessionConfig).loadDeadDropsWithCache()
        XCTAssertTrue(results2?.deadDrops.count == 4)
    }

    func testCacheFileDoesNotGetTooLarge() async throws {
        try await removeDeadDropCacheFile()
        // fill the cache file with 1000 deadDrops
        let maxDeadDropId = 1000
        let twoWeeksInSeconds = 60 * 60 * 24 * 14
        // add a dead drop every 3 mins over 14 days but 2 weeks in the past
        let threeMinsInSeconds = TimeInterval(3 * 60)

        var cachedDeadDrops: [DeadDrop] = generateBulkDeadDrops(maxDeadDropId: maxDeadDropId, idOffset: 0, timeSpan: threeMinsInSeconds, timeOffset: TimeInterval(twoWeeksInSeconds))

        // store the dead drops in the cache
        let cached = DeadDropData(deadDrops: cachedDeadDrops)
        try await DeadDropLocalRepository().save(deadDrops: cached)

        // validate the dead drops were saved correctly
        let cachedDeadDropFromFile = try await DeadDropLocalRepository().load()
        XCTAssertTrue(cachedDeadDropFromFile.deadDrops.count == 1001)

        // generate more dead drops to be returned as part of the dead drop api mock response
        let apiResponseDeadDropIdOffset = 2000
        var apiResponseDeadDrops: [DeadDrop] = generateBulkDeadDrops(maxDeadDropId: maxDeadDropId, idOffset: apiResponseDeadDropIdOffset, timeSpan: threeMinsInSeconds, timeOffset: TimeInterval(0))
        guard let deadDropJsonResponse = try? JSONEncoder().encode(DeadDropData(deadDrops: apiResponseDeadDrops))
        else {
            XCTFail("Unable to create mock json dead drop response")
            return
        }

        // This sets up the mock api response
        // In the DeadDropWebRepository we use the highest dead drop Id from the cache as the `ids_greater_than`
        // So this sets up a mock response for that specific request
        let baseUrl = DevConfig().apiBaseUrl
        let deadDropAPIPath = DeadDropWebRepository.API.allDeadDrops(idsGreaterThan: maxDeadDropId).path

        let deadDropDataResponse = Data(deadDropJsonResponse)
        let deadDropMockApiResponse = [URL(string: "\(baseUrl + deadDropAPIPath)")!: MockResponse(
            error: nil,
            data: deadDropDataResponse,
            response: HTTPURLResponse(url: URL(string: "\(baseUrl + deadDropAPIPath)")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )]

        let urlSessionConfig = mockApiResponse(mockData: deadDropMockApiResponse)

        // check the file size stays consistant, we do this by checking that
        // the count of dead drops stays at 1001, because all the previous dead drops will have been removed
        // as they are 2 weeks older that the most recent loaded dead drop
        // We check that the highest dead drop id is 3000, which means the files in cache also have the most recent from the api response.

        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 90), urlSession: urlSessionConfig).loadDeadDropsWithCache()
        XCTAssertTrue(results?.deadDrops.count == 1001)
        let highestStoredDeadDrop = results?.deadDrops.max(by: { $0.id < $1.id })?.id
        XCTAssertTrue(highestStoredDeadDrop == 3000)
    }

    func generateBulkDeadDrops(maxDeadDropId: Int, idOffset: Int, timeSpan: TimeInterval, timeOffset: TimeInterval) -> [DeadDrop] {
        var cachedDeadDrops: [DeadDrop] = []
        for deadDropId in Array(0 ... maxDeadDropId) {
            let deadDropDate = Date(timeIntervalSinceNow: -((Double(deadDropId) * timeSpan) + timeOffset))

            let deadDrop = fakeUserFacingDeadDrop(id: deadDropId + idOffset, createdAt: deadDropDate)
            cachedDeadDrops.append(deadDrop)
        }
        return cachedDeadDrops
    }

    /// This overrides the default UrlSessionConfig in our global Config Object, so that calls to our public keys endpoint
    /// return the mock data supplied
    func mockApiResponse(mockData: [URL?: MockResponse] = [:]) -> URLSession {
        let suppliedMockData = (mockData.isEmpty) ? MockUrlData.getMockUrlData() : mockData

        let urlSessionConfig = URLSessionConfiguration.ephemeral
        URLProtocolMock.mockURLs = suppliedMockData
        urlSessionConfig.protocolClasses = [URLProtocolMock.self]
        let urlSession = URLSession(configuration: urlSessionConfig)
        return urlSession
    }

    func mockApiResponseFailure() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        URLProtocolMock.mockURLs = [:]
        urlSessionConfig.protocolClasses = [URLProtocolMock.self]
        let urlSession = URLSession(configuration: urlSessionConfig)
        return urlSession
    }
}
