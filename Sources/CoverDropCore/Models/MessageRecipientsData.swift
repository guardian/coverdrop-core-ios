import Foundation

public struct MessageRecipients {
    public enum RecipientsError: Error {
        case recipientsUnavailable

        var localizedDescription: String {
            switch self {
            case .recipientsUnavailable:
                return "Unable to fetch recipients. Please check your internet connection."
            }
        }
    }

    public private(set) var journalists: [JournalistData] = []
    public private(set) var desks: [JournalistData] = []
    public private(set) var defaultRecipient: JournalistData?

    /// Sets up message recipients and sorts into relevant local properties using the provided public keys.
    /// - Parameters:
    ///   - verifiedPublicKeys:
    ///   - excludingDefaultRecipient: Exclude the default recipient from the `journalists` and `desks` arrays. Defaults to `true`.
    public init(verifiedPublicKeys: VerifiedPublicKeys?,
                excludingDefaultRecipient: Bool = true) throws {
        try setupMessageRecipients(with: verifiedPublicKeys, excludingDefaultRecipient: excludingDefaultRecipient)
    }

    private mutating
    func setupMessageRecipients(with verifiedPublicKeys: VerifiedPublicKeys?,
                                excludingDefaultRecipient: Bool = true) throws {
        guard let verifiedPublicKeys else {
            throw RecipientsError.recipientsUnavailable
        }

        for journalistProfile in verifiedPublicKeys.journalistProfiles {
            // make sure there are some public keys for the journalist
            let allJournalistKeys = verifiedPublicKeys.allMessageKeysForJournalistId(journalistId: journalistProfile.id)
            // make sure there is a messaging key
            if allJournalistKeys.isEmpty { return }

            let journalistKeyData = JournalistData(
                recipientId: journalistProfile.id,
                displayName: journalistProfile.displayName,
                isDesk: journalistProfile.isDesk,
                recipientDescription: journalistProfile.description,
                tag: RecipientTag(tag: journalistProfile.tag.bytes)
            )

            // if the journalist is the default journalist
            if journalistKeyData.recipientId == verifiedPublicKeys.defaultJournalistId {
                defaultRecipient = journalistKeyData
                if excludingDefaultRecipient == true {
                    return
                }
            }

            if journalistKeyData.isDesk {
                desks.append(journalistKeyData)
            } else {
                journalists.append(journalistKeyData)
            }
        }
    }

    // This is just for testing
    public mutating
    func removeDesks() {
        desks = []
    }
}
