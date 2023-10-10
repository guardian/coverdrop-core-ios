@testable import CoverDropCore
import Sodium
import XCTest

final class PublicKeyRepositoryTests: XCTestCase {
    func removeCurrentCacheFile() async throws {
        let fileManager = FileManager.default
        let fileURL = try await PublicKeyLocalRepository().fileURL()

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(atPath: fileURL.path)
        }
    }

    func testCachedKeysAreLoadedWhenInCacheTimeframe() async throws {
        try await removeCurrentCacheFile()
        // 1. create a local file with valid content using the mock data
        let keys = try PublicKeysHelper.readLocalKeysFile()
        try await PublicKeyLocalRepository().save(publicKeys: keys)
        // 2. call the loadKeys function
        let results = try await PublicKeyRepository().loadKeys()
        // 3. the load keys should have got our file from disk

        XCTAssertTrue(keys == results)
    }

    func testApiIsCalledWhenOutsideCacheTimeframe() async throws {
        try await removeCurrentCacheFile()
            // 1. create a local file with valid content using the mock data
        let keys = try PublicKeysHelper.readLocalKeysFile()
        try await PublicKeyLocalRepository().save(publicKeys: keys)
        // 2. stub the API response to return a valid value
        let urlSessionConfig = mockAPIResponse()
        // 3. call the loadKeys function
        let results = try await PublicKeyRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 48), urlSessionConfig: urlSessionConfig).loadKeys()
        // 4. the load keys should have got our file from disk
        XCTAssertTrue(keys == results)
    }

    func testWhenOutsideCacheTimeframeAndApiFailButFileLoads() async throws {
        try await removeCurrentCacheFile()
        // 3. call the loadKeys function
        let urlSessionConfig = mockApiResponseFailure()

        let keys = try PublicKeysHelper.readLocalKeysFile()
        try await PublicKeyLocalRepository().save(publicKeys: keys)

        let results = try await PublicKeyRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 48), urlSessionConfig: urlSessionConfig).loadKeys()
        // 4. the load keys should have got our file from disk
        XCTAssertTrue(keys == results)
    }

    func testFailsWhenWhenOutsideCacheTimeframeAndFileLoadAndApiFail() async throws {
        var didFailWithError: Error?
        try await removeCurrentCacheFile()
        // 3. call the loadKeys function
        let sessionConfig = mockApiResponseFailure()

        do {
            try await PublicKeyRepository(now: Date(timeIntervalSinceNow: 60 * 60 * 48), urlSessionConfig: sessionConfig).loadKeys()
        } catch {
            didFailWithError = error
        }

        XCTAssertNotNil(didFailWithError)
    }

    /// This overrides the default UrlSessionConfig in our global Config Object, so that calls to our public keys endpoint
    /// return the mock data supplied
    func mockAPIResponse() -> URLSession {
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
