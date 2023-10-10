import Foundation

public struct DeadDropData: Codable {
    public var deadDrops: [DeadDrop]

    enum CodingKeys: String, CodingKey {
        case deadDrops = "dead_drops"
    }
}

// This is used to store the most recent succesufully loaded dead drop Id
public struct DeadDropId: Codable, Comparable {
    public static func < (lhs: DeadDropId, rhs: DeadDropId) -> Bool {
        return lhs.id < rhs.id
    }

    public var id: Int
}

public struct DeadDrop: Codable {
    public var id: Int
    public var createdAt: String?
    public var data: Base64EncodedString
    public var cert: HexEncodedString

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case data
        case cert
    }
}

public struct DeadDropCertificateData: Codable {
    public var data: [UInt8]
}
