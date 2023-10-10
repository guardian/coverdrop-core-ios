@testable import CoverDropCore
import Sodium
import XCTest

final class UserToJournalistMessageRepositoryTests: XCTestCase {
    func testSendMessageError() async throws {
        let urlSessionConfig = mockApiResponseFailure()

        let numRecipients = 1
        let bytesLength = (numRecipients * Sodium().secretBox.KeyBytes + Sodium().box.SealBytes) + Sodium().secretBox.MacBytes

        let bytes = Sodium().randomBytes.buf(length: bytesLength)!

        let testMessage = MultiAnonymousBox<UserToCoverNodeMessageData>(bytes: bytes)
        do {
            let results = try await UserToJournalistMessageWebRepository(session: urlSessionConfig).sendMessage(message: testMessage)
            XCTFail("API error should have failed")
        } catch {}
    }

    func testSendMessageSuccess() async throws {
        let urlSessionConfig = mockApiResponse()

        let numRecipients = 1
        let bytesLength = (numRecipients * Sodium().secretBox.KeyBytes + Sodium().box.SealBytes) + Sodium().secretBox.MacBytes

        let bytes = Sodium().randomBytes.buf(length: bytesLength)!

        let testMessage = MultiAnonymousBox<UserToCoverNodeMessageData>(bytes: bytes)
        do {
            let results = try await UserToJournalistMessageWebRepository(session: urlSessionConfig).sendMessage(message: testMessage)
        } catch {
            XCTFail("API error should have failed")
        }
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
