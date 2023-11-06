import Foundation
import Sodium

typealias JournalistToUserMessage = TwoPartyBox<[UInt8]>

enum VerificationDeadDropError: Error {
    case deadDropDataWrongSize
}

/// This is a list of verified dead drops
/// Each dead drop has been verified before passed into this container
public struct VerifiedDeadDrops {
    var deadDrops: [VerifiedDeadDrop]
}

public extension VerifiedDeadDrops {
    /// Converts unverfied DeadDropData loaded from the user dead drop API
    /// into VerifiedDeadDropData by checking that each dead drop
    /// has been signed by the CoverNodeId Public Key
    /// - Parameters:
    ///   - deadDrops: A list of DeadDrops
    ///   - signingPk: The signing public key - in this case a CoverNodeIdPublicKey used to verify the dead drops
    /// - Returns: a VerifiedDeadDrops struct - only dead drops that are verified are returned
    static func fromAllDeadDropData(deadDrops: DeadDropData, verifiedKeys: VerifiedPublicKeys) -> VerifiedDeadDrops {
        let verifiedDeadDrops = allVerifiedDeadDropsFromDeadDropData(deadDrops: deadDrops, verifiedKeys: verifiedKeys)

        return VerifiedDeadDrops(deadDrops: verifiedDeadDrops)
    }

    static func allVerifiedDeadDropsFromDeadDropData(deadDrops: DeadDropData, verifiedKeys: VerifiedPublicKeys) -> [VerifiedDeadDrop] {
        var verifiedDeadDrops: [VerifiedDeadDrop] = []

        let coverNodeIdKeys: [String: [CoverNodeIdPublicKey]] = verifiedKeys.getAllCoverNodeIdKeys()

        deadDrops.deadDrops.forEach { deadDrop in
            coverNodeIdKeys.values.forEach { coverNodeIdKey in
                coverNodeIdKey.forEach { key in
                    if let verfiedDeadDrop = VerifiedDeadDrop(unverifiedDeadDrop: deadDrop, signingPk: key) {
                        verifiedDeadDrops.append(verfiedDeadDrop)
                    }
                }
            }
        }

        return verifiedDeadDrops
    }

    internal func getMostRecentId() -> Int? {
        deadDrops.map { $0.id }.max()
    }
}

/// An individual dead drop that has been verified against the CoverNodeId Public Signing Key.
public struct VerifiedDeadDrop {
    var id: Int
    var data: [JournalistToUserMessage]
    var publishedDate: Date

    /// Failable initialiser for the a VerifiedDeadDrop - it will fail if the verification is unsuccessful
    /// - Parameters:
    ///   - unverifiedDeadDrop: the unverified dead drop for verification
    ///   - signingPk: the CoverNodeIdPublicKey used to sign the dead drops
    init?(unverifiedDeadDrop: DeadDrop, signingPk: CoverNodeIdPublicKey) {
        let unverifiedDeadDropCertificateData = DeadDropCertificateData(data: unverifiedDeadDrop.cert.bytes)

        do {
            if VerifiedDeadDrop.verify(
                signingPk: signingPk,
                data: unverifiedDeadDrop.data.bytes,
                signature: Signature.fromBytes(bytes: unverifiedDeadDropCertificateData.data)
            ) {
                let parsedDeadDropData = try VerifiedDeadDrop.parseDeadDropData(data: unverifiedDeadDrop.data.bytes)
                let validDeadDropDate = unverifiedDeadDrop.createdAt.date
                // Check the deaddrop publish date is not more that 1 week in the future
                // This is to make sure no-one has tampered with the deaddrop api dates.
                let isValidDateLessThan7DaysInTheFuture = Date().distance(to: validDeadDropDate) < 60 * 60 * 24 * 7
                if isValidDateLessThan7DaysInTheFuture {
                    id = unverifiedDeadDrop.id
                    data = parsedDeadDropData
                    publishedDate = validDeadDropDate
                } else { return nil }
            } else { return nil }
        } catch { return nil }
    }

    /// Parse the verified dead drop data into a list of JournalistToUserMessages
    /// The entire dead drop data byte array is a fixed sized list of TwoPartyBoxes
    /// https://github.com/guardian/coverdrop/blob/main/docs/protocol_messages.md#journalist-to-user-message
    /// This function splits the dead drop data into a list of JournalistToUserMessages
    /// - Parameter data: raw dead drop data
    /// - Returns:  a list of JournalistToUserMessages
    /// - throws: If any of chunked dead drop data is not the correct size
    static func parseDeadDropData(data: [UInt8]) throws -> [JournalistToUserMessage] {
        let deadDropFromData = data.chunked(into: Constants.journalistToUserEncryptedMessageLen)

        return try deadDropFromData.map { unverifiedDeadDrop in
            if unverifiedDeadDrop.count != Constants.journalistToUserEncryptedMessageLen {
                throw VerificationDeadDropError.deadDropDataWrongSize
            }
            let journalistToUserMessage: JournalistToUserMessage = TwoPartyBox<PaddedCompressedString>.fromVecUnchecked(bytes: unverifiedDeadDrop)
            return journalistToUserMessage
        }
    }

    /// Verifies a dead drop data byte array against its certificate and CoverNodeId Public Key
    /// - Parameters:
    ///   - signingPk: the CoverNodeId Public Key for the Private Key used to sign the dead drop data
    ///   - data: the dead drop data
    ///   - signature: the signature provided alongside the dead drop data in the API respose
    /// - Returns: `true` if the verfication is sucessful, `false` if verification fails
    static func verify(signingPk: CoverNodeIdPublicKey,
                       data: [UInt8],
                       signature: Signature<CoverNodeId>) -> Bool
    {
        return Sodium().sign.verify(message: data, publicKey: signingPk.key, signature: signature.certificate)
    }
}
