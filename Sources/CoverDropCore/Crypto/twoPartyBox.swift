import Foundation
import Sodium

/// Intended for public key cryptography where both parties are known and can message each other.
///
/// Internally uses `libsodium`'s [`crypto_box`] primitives. Unlike `libsodium` we handle generating
/// a nonce and appending it to the outputted ciphertext and tag bytes.
///
/// The box does not handle the sharing public key. The public keys must be shared in some other way,
/// either passed in plaintext along with the ciphertex message or through public key infrastrcture.
///
/// Like [`SecretBox`], `AnonymousBox` works with types that implement [`Encryptable`].
///
/// [`Encryptable`]: super::Encryptable
/// [`SecretBox`]: super::SecretBox
/// [`crypto_box`]: https://libsodium.gitbook.io/doc/public-key_cryptography/authenticated_encryption
///
/// Please read `https://github.com/guardian/coverdrop/blob/main/docs/cryptography.md` for details on `TwoPartyBox` functions
public struct TwoPartyBox<T> {
    var tagCiphertextAndNonce: [UInt8]
}

public extension TwoPartyBox {
    static func fromVecUnchecked<T: Encryptable>(bytes: [UInt8]) -> TwoPartyBox<T> {
        return TwoPartyBox<T>(
            tagCiphertextAndNonce: bytes
        )
    }

    func asBytes() -> [UInt8] {
        tagCiphertextAndNonce
    }

    static func encrypt<T: Encryptable>(
        recipientPk: PublicEncryptionKey<JournalistMessaging>,
        senderSk: SecretEncryptionKey<User>,
        data: T
    ) throws -> TwoPartyBox<T> {
        let nonce = Sodium().box.nonce()

        if var tagAndCiphertext: [UInt8] = Sodium().box.seal(message: data.asUnencryptedBytes(), recipientPublicKey: recipientPk.key, senderSecretKey: senderSk.key, nonce: nonce) {
            tagAndCiphertext.append(contentsOf: nonce)

            let tagCiphertextAndNonce = tagAndCiphertext

            return TwoPartyBox<T>(tagCiphertextAndNonce: tagCiphertextAndNonce)
        } else {
            throw EncryptionError.failedToDecrypt
        }
    }

    static func decrypt<T: Encryptable>(
        senderPk: PublicEncryptionKey<JournalistMessaging>,
        recipientSk: SecretEncryptionKey<User>,
        data: TwoPartyBox<T>
    ) throws -> T {
        let bytes = data.tagCiphertextAndNonce
        let nonceStart = bytes.count - Sodium().box.NonceBytes
        // get the nonce from the end of tagCiphertextAndNonce
        let nonce = Array(bytes.suffix(Sodium().box.NonceBytes))
        // get the ciphertext from the begining of tagCiphertextAndNonce
        let cipherTestBytes = Array(bytes.prefix(nonceStart))

        if let plaintextBytes = Sodium().box.open(authenticatedCipherText: cipherTestBytes, senderPublicKey: senderPk.key, recipientSecretKey: recipientSk.key, nonce: nonce) {
            return try T.fromUnencryptedBytes(bytes: plaintextBytes) as! T
        } else {
            throw EncryptionError.failedToDecrypt
        }
    }
}
