@testable import CoverDropCore
import Sodium
import XCTest

final class VerifiedKeysTests: XCTestCase {
    func testPublicKeysData() -> PublicKeysData? {
        let testData = try? FileHelper.dataFromFile(filePath: "static_vectors/verifiedKeys", fileExtension: "json")
        guard let data = testData else { return nil }
        return try? JSONDecoder().decode(PublicKeysData.self, from: testData!)
    }

    func getVerifiedKeysFromVector() -> VerifiedPublicKeys? {
        guard let publicKeysData = testPublicKeysData(),
              let key = publicKeysData.keys.first?.organizationPublicKey else
        {
            return nil
        }
        // this sets the current date in the correct time period for the static vector
        let yearAgo = TimeInterval(-60 * 60 * 24 * 365)
        let currentDate = key.notValidAfter.date.advanced(by: yearAgo)

        guard let trustedOrganizationPublicKey = SelfSignedPublicSigningKey<TrustedOrganization>.init(key: Sign.KeyPair.PublicKey(key.key.bytes), certificate: Signature<TrustedOrganization>.fromBytes(
            bytes: key.certificate.bytes), notValidAfter: key.notValidAfter.date, now: currentDate) else
        {
            return nil
        }

        let trustedOrganizationPublicKeys = [trustedOrganizationPublicKey]

        let verifiedPublicKeys = VerifiedPublicKeys(publicKeysData: publicKeysData, trustedOrganizationPublicKeys: trustedOrganizationPublicKeys, currentTime: currentDate)
        return verifiedPublicKeys
    }

    func testGetCoverNodeKeys() throws {
        guard let verifiedPublicKeys = getVerifiedKeysFromVector() else {
            XCTFail("Failed to get verified keys")
            return
        }
        let mostRecentCoverNodeMessagingKeysFromAllHierarchies: [CoverNodeIdentity: CoverNodeMessagingPublicKey] = verifiedPublicKeys.mostRecentCoverNodeMessagingKeysFromAllHierarchies()
        let expectedKey = "0ce3afeaad3930e9f40555d119c09efcbcf215b7553b08889a4920b8c55a241e"

        guard let coverNodeKey = mostRecentCoverNodeMessagingKeysFromAllHierarchies["covernode_001"]?.key.key.hexStr else {
            XCTFail("Failed to get coverNodeKey")
            return
        }

        XCTAssertTrue(coverNodeKey == expectedKey)
    }

    func testGetJounalistMessagingKeys() throws {
        guard let verifiedPublicKeys = getVerifiedKeysFromVector() else {
            XCTFail("Failed to get verified keys")
            return
        }
        let expectedKey = "9d76075636f422fec1f14913b1a2ba07b4bc9979525c95c9963963a3800f3743"
        let journalistMessageKeys = verifiedPublicKeys.allMessageKeysForJournalistId(journalistId: "rosalind_franklin1")
        guard let mostRecentKey = journalistMessageKeys.max(by: { $0.notValidAfter < $1.notValidAfter })?.key.key.hexStr else {
            XCTFail("Failed to get recent keys")
            return
        }
        XCTAssertTrue(mostRecentKey == expectedKey)
    }
}
