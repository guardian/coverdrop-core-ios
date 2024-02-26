@testable import CoverDropCore
import XCTest

final class SecretDataTests: XCTestCase {
    func testGetJournalistKeyDataForJournalistId() async throws {
        let journlistId = "static_test_journalist"

        PublicDataRepository.setup(StaticConfig.devConfig)

        let data = await UnlockedSecretDataService.getJournalistKeyDataForJournalistId(journalistId: journlistId, publicKeyData: PublicKeysHelper.shared.testKeys)

        XCTAssertEqual(data?.recipientId, journlistId)
    }
}
