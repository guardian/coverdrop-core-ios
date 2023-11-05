@testable import CoverDropCore
import XCTest

final class SecretDataTests: XCTestCase {
    func testGetJournalistKeyDataForJournalistId() async throws {
        let journlistId = "static_test_journalist"

        PublicDataRepository.setup(ConfigType.devConfig)
        PublicDataRepository.shared.verifiedPublicKeysData = PublicKeysHelper.shared.testKeys

        let data = await UnlockedSecretData.getJournalistKeyDataForJournalistId(journalistId: journlistId)

        XCTAssertEqual(data?.recipientId, journlistId)
    }
}
