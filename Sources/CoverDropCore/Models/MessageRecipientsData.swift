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
            guard let allJournalistKeys = verifiedPublicKeys.allPublicKeysForJournalistsFromAllHierarchies()[journalistProfile.id] else { return }
            guard let recentJournalistKey = allJournalistKeys.max(by: { $0.id.notValidAfter < $1.id.notValidAfter }) else { return }

            let journalistKeyData = JournalistData(recipientId: journalistProfile.id,
                                                      displayName: journalistProfile.displayName,
                                                      isDesk: journalistProfile.isDesk,
                                                      recipientDescription: journalistProfile.description,
                                                      tag: RecipientTag(tag: journalistProfile.tag.bytes))

            // if the journalist is the default journalist
            if journalistKeyData.recipientId == verifiedPublicKeys.defaultJournalistId {
                defaultRecipient = journalistKeyData

                // but if we are not excluding the default journalist from the results
                if excludingDefaultRecipient == false {
                    if journalistKeyData.isDesk {
                        desks.append(journalistKeyData)
                    } else {
                        journalists.append(journalistKeyData)
                    }
                }

            } else if journalistKeyData.isDesk {
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
