import Combine
import Foundation

public enum Message: Codable, Equatable, Hashable, Comparable {
    case outboundMessage(message: OutboundMessageData)
    case incomingMessage(message: IncomingMessageType)

    public func getDate() -> Date {
        switch self {
        case let .incomingMessage(message: incomingMessage):
            switch incomingMessage {
            case let .handoverMessage(message: message):
                return message.timestamp
            case let .textMessage(message: message):
                return message.dateReceived
            }
        case let .outboundMessage(message: message):
            return message.dateQueued
        }
    }

    static func formatExpiryDate(messageDate: Date, expiry: Date) -> String? {
        let timeTillExpiry = expiry.distance(to: messageDate)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour]
        let formattedExpiry = formatter.string(from: timeTillExpiry)
        return formattedExpiry
    }

    public static var expiryWindow: Date {
        let expiryWindow = Constants.messageValidForDurationInSeconds
        let expiryDate = Date(timeIntervalSinceNow: TimeInterval(1 - expiryWindow))
        return expiryDate
    }

    public static func getExpiredStatus(dateSentOrReceived: Date) -> MessageStatus {
        if Message.isExpiring(dateSentOrReceived: dateSentOrReceived) {
            if let formattedExpiry = Message.formatExpiryDate(messageDate: dateSentOrReceived, expiry: Message.expiryWindow) {
                return .expiring(time: formattedExpiry)
            } else {
                return .pendingOrSent
            }
        } else {
            return .pendingOrSent
        }
    }

    private static func isExpiring(dateSentOrReceived: Date) -> Bool {
        let expiryWarningDuration = Double(Constants.messageExpiryWarningInSeconds)
        return Message.expiryWindow.distance(to: dateSentOrReceived) < expiryWarningDuration
    }
}

public enum MessageStatus {
    case pendingOrSent, expiring(time: String)
}

enum OutboundMessageError: Error {
    case missingRecipientError
}

public class OutboundMessageData: Hashable, Codable, Comparable, ObservableObject {
    public var recipient: JournalistData
    public var messageText: String = ""
    public var dateQueued: Date = .now
    // Note that hint is optional as it cannot be known on first initalisation
    // this is because the hint is derived from the encrypted form of the message,
    // so it appended to the message after its been enqueued
    public var hint: HintHmac?

    @MainActor @Published public var isPending: Bool = true
    private var sendingQueueSubscriber: AnyCancellable?

    private enum CodingKeys: String, CodingKey {
        case recipient, messageText, dateQueued, isPending
    }

    @MainActor public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipient = try container.decode(JournalistData.self, forKey: .recipient)
        messageText = try container.decode(String.self, forKey: .messageText)
        dateQueued = try container.decode(Date.self, forKey: .dateQueued)
        isPending = try container.decode(Bool.self, forKey: .isPending)
    }

    @MainActor public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recipient, forKey: .recipient)
        try container.encode(messageText, forKey: .messageText)
        try container.encode(dateQueued, forKey: .dateQueued)
        try container.encode(isPending, forKey: .isPending)
    }

    public static func == (lhs: OutboundMessageData, rhs: OutboundMessageData) -> Bool {
        return lhs.messageText == rhs.messageText &&
            lhs.recipient == rhs.recipient &&
            lhs.dateQueued == rhs.dateQueued
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(dateQueued)
        hasher.combine(recipient)
        hasher.combine(messageText)
    }

    public static func < (lhs: OutboundMessageData, rhs: OutboundMessageData) -> Bool {
        return lhs.dateQueued < rhs.dateQueued
    }

    @MainActor public func isInQueue() async {
        if let realHint = hint {
            let amInQueue = await PrivateSendingQueueRepository.shared.isMessageInQueue(hint: realHint)
            isPending = amInQueue
        }
    }

    public var expiredStatus: MessageStatus {
        return Message.getExpiredStatus(dateSentOrReceived: dateQueued)
    }

    @MainActor public init(recipient: JournalistData, messageText: String, dateSent: Date, hint: HintHmac? = nil) {
        self.recipient = recipient
        self.messageText = messageText
        dateQueued = dateSent
        self.hint = hint
        Task {
            sendingQueueSubscriber = await PrivateSendingQueueRepository.shared.$lastUpdated
                .sink { [weak self] _ in
                    Task { await self?.isInQueue() }
                }
        }
    }

    public func toCoverNodeMessage(covernodeMessagePublicKey: VerifiedPublicKeys, userPublicKey: UserPublicKey) async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        if let messageKey = recipient.getMessageKey() {
            return try await UserToCoverNodeMessage.createMessage(message: messageText, recipientPublicKey: messageKey, coverNodesToMostRecentMessagePublicKey: covernodeMessagePublicKey, userPublicKey: userPublicKey, tag: recipient.tag)
        } else {
            throw KeysError.cannotFindFileError
        }
    }
}

extension OutboundMessageData: CustomStringConvertible {
    public var description: String {
        """
             recipient: \(recipient)
             messageText: \(messageText)
             dateQueued: \(dateQueued)
        """
    }
}

public enum IncomingMessageType: Hashable, Codable, Comparable {
    case textMessage(message: IncomingMessageData)
    case handoverMessage(message: HandoverMessageData)
}

public struct HandoverMessageData: Hashable, Codable, Comparable {
    public static func < (lhs: HandoverMessageData, rhs: HandoverMessageData) -> Bool {
        return lhs.handoverTo < rhs.handoverTo &&
            lhs.sender < rhs.sender &&
            lhs.timestamp < rhs.timestamp
    }

    public static func == (lhs: HandoverMessageData, rhs: HandoverMessageData) -> Bool {
        return lhs.handoverTo == rhs.handoverTo &&
            lhs.sender == rhs.sender &&
            lhs.timestamp == rhs.timestamp
    }

    init?(sender: JournalistData, timestamp: Date, handoverTo: String) {
        if handoverTo.count > DeadDropMessageParser.journalistIdentityMaxLength {
            return nil
        }
        self.handoverTo = handoverTo
        self.sender = sender
        self.timestamp = timestamp
    }

    public var sender: JournalistData
    public var timestamp: Date
    public var handoverTo: String
}

public struct IncomingMessageData: Hashable, Codable, Comparable {
    public var sender: JournalistData
    public var messageText: String
    public var dateReceived: Date
    public var deadDropId: Int

    public static func < (lhs: IncomingMessageData, rhs: IncomingMessageData) -> Bool {
        return lhs.dateReceived < rhs.dateReceived
    }

    public var expiredStatus: MessageStatus {
        return Message.getExpiredStatus(dateSentOrReceived: dateReceived)
    }

    public init(sender: JournalistData, messageText: String, dateReceived: Date, deadDropId: Int = 0) {
        self.sender = sender
        self.messageText = messageText
        self.dateReceived = dateReceived
        self.deadDropId = deadDropId
    }
}
