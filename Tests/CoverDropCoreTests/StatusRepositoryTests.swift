@testable import CoverDropCore
import Sodium
import XCTest

final class StatusRepositoryTests: XCTestCase {
    let config: StaticConfig = .devConfig

    func removeStatusCacheFile() async throws {
        let fileManager = FileManager.default
        let fileURL = try await StatusLocalRepository().fileURL()

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(atPath: fileURL.path)
        }
    }

    func testFirstRunDoesNotCacheIfAPIResponseFailedAndCacheDisabled() async throws {
        try await removeStatusCacheFile()

        let urlSession = mockApiResponseFailure()

        let results = try await StatusRepository(config: config, urlSession: urlSession)
            .downloadAndUpdateAllCaches(cacheEnabled: false)

        XCTAssertTrue(results?.status == .unavailable)
    }

    func testFirstRunWithOutsideCacheWindowApiResponseLoadsDeadDropsAndCacheDisabled() async throws {
        try await removeStatusCacheFile()

        let urlSession = mockApiResponse()

        // note we are outside the cache window
        let results = try await StatusRepository(
            now: Date(timeIntervalSinceNow: 60 * 60 * 48),
            config: config,
            urlSession: urlSession
        ).downloadAndUpdateAllCaches(cacheEnabled: false)
        XCTAssertTrue(results?.status == .available)
    }

    func testFirstRunReturnsDefaultStatusIfAPIResponseFails() async throws {
        try await removeStatusCacheFile()

        let urlSession = mockApiResponseFailure()

        let results = try await StatusRepository(config: config, urlSession: urlSession)
            .downloadAndUpdateAllCaches()

        XCTAssertTrue(results?.status == .unavailable)
    }

    func testFirstRunWithOutsideCacheWindowApiResponseLoadsDeadDrops() async throws {
        try await removeStatusCacheFile()

        let urlSession = mockApiResponse()

        // note we are outside the cache window
        let results = try await StatusRepository(
            now: Date(timeIntervalSinceNow: 60 * 60 * 48),
            config: config,
            urlSession: urlSession
        ).downloadAndUpdateAllCaches()

        XCTAssertTrue(results?.status == .available)
    }

    func testFirstRunInsideCacheWindowWithApiResponseLoadsStatusAndCachesResponse() async throws {
        try await removeStatusCacheFile()

        let urlSession = mockApiResponse()
        // note we are intside the cache window
        let results = try await StatusRepository(
            now: Date(timeIntervalSinceNow: 60 * 50),
            config: config,
            urlSession: urlSession
        ).downloadAndUpdateAllCaches()
        let cache = try await StatusLocalRepository().load()
        XCTAssertEqual(results, cache)
    }

    func testFutureRunOutsideCacheWindowWithApiResponseLoadsStatusButNotUpdateId() async throws {
        try await removeStatusCacheFile()

        let urlSession = mockApiResponse()
        // note we are outside the cache window
        let results = try await StatusRepository(
            now: Date(timeIntervalSinceNow: 60 * 60 * 2),
            config: config,
            urlSession: urlSession
        ).downloadAndUpdateAllCaches()
        let cache = try await StatusLocalRepository().load()
        XCTAssertEqual(results, cache)
    }

    func testFutureRunInsideCacheWindowWithFailedApiResponseReturnsDefaults() async throws {
        try await removeStatusCacheFile()
        let urlSession = mockApiResponseFailure()

        // note we are inside the cache window
        let results = try await StatusRepository(
            now: Date(timeIntervalSinceNow: 60 * 50),
            config: config,
            urlSession: urlSession
        ).downloadAndUpdateAllCaches(cacheEnabled: false)

        XCTAssertTrue(results?.status == .unavailable)
    }

    func testCacheInsideCacheWindowUpdatesCache() async throws {
        try await removeStatusCacheFile()
        let urlSession = mockApiResponse()

        let results = try await StatusRepository(
            now: Date(timeIntervalSinceNow: 60 * 90),
            config: config,
            urlSession: urlSession
        ).downloadAndUpdateAllCaches()
        let results2 = try await StatusRepository(
            now: Date(timeIntervalSinceNow: 60 * 90),
            config: config,
            urlSession: urlSession
        ).downloadAndUpdateAllCaches()

        XCTAssertEqual(results, results2)
    }

    /// This overrides the default urlSession in our global Config Object, so that calls to our public keys
    /// endpoint
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
