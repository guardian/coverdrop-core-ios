import Foundation

public enum CoverMessageError: Error {
    case failedToGetCoverNodeMessageKeys
    case failedToCreateCoverMessage
}

public enum CoverMessage {
    public static func getCoverMessage() throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        let publicDataRepository = PublicDataRepository.shared
        guard let allCoverNodes = publicDataRepository.verifiedPublicKeysData?.mostRecentCoverNodeMessagingKeysFromAllHierarchies() else {
            throw CoverMessageError.failedToGetCoverNodeMessageKeys
        }
        let coverNodeKeys = UserToCoverNodeMessage.selectCovernodeKeys(coverNodeKeys: allCoverNodes)
        guard let coverMessage = try? PublicDataRepository.shared.createCoverMessageToCoverNode(coverNodeKeys: coverNodeKeys) else {
            throw CoverMessageError.failedToCreateCoverMessage
        }
        return coverMessage
    }
}
