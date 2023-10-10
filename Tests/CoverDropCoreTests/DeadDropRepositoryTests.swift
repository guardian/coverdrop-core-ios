@testable import CoverDropCore
import Sodium
import XCTest

final class DeadDropRepositoryTests: XCTestCase {
    func removeCurrentCacheFile() async throws {
        let fileManager = FileManager.default
        let fileURL = try await DeadDropIdRepository().fileURL()

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(atPath: fileURL.path)
        }
    }

    func testFirstRunCreatesFileAndLoadsDeadDropsFromZero() async throws {
        try await removeCurrentCacheFile()

        let urlSessionConfig = mockApiResponseFailure()

        let results = try await DeadDropRepository(urlSession: urlSessionConfig).loadDeadDrops()

        let deadDropId = try await DeadDropIdRepository().load()

        // 3. the load keys should have got our file from disk
        XCTAssertTrue(deadDropId.id == 0)
    }

    func testFirstRunWithOutsideCacheWindowApiResponseLoadsDeadDropsButNotUpdateId() async throws {
        try await removeCurrentCacheFile()

        let urlSessionConfig = mockApiResponse()

        try await DeadDropIdRepository().save(deadDrops: DeadDropId(id: 0))
        // note we are outside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 48), urlSession: urlSessionConfig).loadDeadDrops()

        let deadDropId = try await DeadDropIdRepository().load()

        XCTAssertFalse(results!.deadDrops.isEmpty)
    }

    func testFirstRunInsideCacheWindowWithApiResponseLoadsDeadDropsButNotUpdateId() async throws {
        try await removeCurrentCacheFile()

        let urlSessionConfig = mockApiResponse()

        try await DeadDropIdRepository().save(deadDrops: DeadDropId(id: 0))
        // note we are outside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 50), urlSession: urlSessionConfig).loadDeadDrops()

        let deadDropId = try await DeadDropIdRepository().load()

        XCTAssertFalse(results!.deadDrops.isEmpty)
    }

    func testFutureRunOutsideCacheWindowWithApiResponseLoadsDeadDropsButNotUpdateId() async throws {
        try await removeCurrentCacheFile()

        let urlSessionConfig = mockApiResponse()

        try await DeadDropIdRepository().save(deadDrops: DeadDropId(id: 0))
        // note we are outside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 2), urlSession: urlSessionConfig).loadDeadDrops()

        let deadDropId = try await DeadDropIdRepository().load()

        XCTAssertFalse(results!.deadDrops.isEmpty)
    }

    func testFutureRunInsideCacheWindowWithFailedApiResponseDoesNotLoadsDeadDrop() async throws {
        try await removeCurrentCacheFile()

        try await DeadDropIdRepository().save(deadDrops: DeadDropId(id: 0))

        let urlSessionConfig = mockApiResponseFailure()

        // note we are outside the cache window
        let results = try await DeadDropRepository(now: Date(timeIntervalSinceNow: 60 * 50), urlSession: urlSessionConfig).loadDeadDrops(cacheEnabled: false)

        XCTAssertTrue(results == nil)
    }

    /// This overrides the default UrlSessionConfig in our global Config Object, so that calls to our public keys endpoint
    /// return the mock data supplied
    func mockApiResponse() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        URLProtocolMock.mockURLs = MockUrlData.getMockUrlData()
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
