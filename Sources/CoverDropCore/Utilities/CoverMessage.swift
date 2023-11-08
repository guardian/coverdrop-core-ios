import Foundation

public enum CoverMessageError: Error {
    case failedToGetCoverNodeMessageKeys
    case failedToCreateCoverMessage
}

public enum CoverMessage {
    public static func getCoverMessage(verifiedPublicKeys: VerifiedPublicKeys) throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        let allCoverNodes = verifiedPublicKeys.mostRecentCoverNodeMessagingKeysFromAllHierarchies()
        if allCoverNodes.isEmpty {
            throw CoverMessageError.failedToGetCoverNodeMessageKeys
        }
        let coverNodeKeys = UserToCoverNodeMessage.selectCovernodeKeys(coverNodeKeys: allCoverNodes)
        guard let coverMessage = try? PublicDataRepository.shared.createCoverMessageToCoverNode(coverNodeKeys: coverNodeKeys) else {
            throw CoverMessageError.failedToCreateCoverMessage
        }
        return coverMessage
    }
}
