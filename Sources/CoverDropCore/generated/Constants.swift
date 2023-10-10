// DO NOT EDIT! This file is auto-generated from Rust code using the following command:
// `cargo run --bin admin generate-mobile-constants-files`.
//
// The Rust code is here: common/src/protocol/constants.rs

public struct Constants {
    public static let journalistProvisioningKeyValidDurationSeconds = 14515200
    public static let journalistIdKeyValidDurationSeconds = 4838400
    public static let journalistMsgKeyValidDurationSeconds = 604800
    public static let covernodeProvisioningKeyValidDurationSeconds = 14515200
    public static let covernodeIdKeyValidDurationSeconds = 2419200
    public static let covernodeMsgKeyValidDurationSeconds = 1209600
    public static let userToCovernodeEncryptedMessageLen = 516
    public static let userToCovernodeMessageLen = 340
    public static let userToJournalistEncryptedMessageLen = 336
    public static let userToJournalistPaddedMessageLen = 288
    public static let journalistToCovernodeEncryptedMessageLen = 473
    public static let journalistToCovernodeMessageLen = 297
    public static let journalistToUserEncryptedMessageLen = 296
    public static let journalistToUserPaddedMessageLen = 256
    public static let messagePaddingLen = 256
    public static let recipientTagLen = 4
    public static let realOrCoverByteLen = 1
    public static let x25519PublicKeyLen = 32
    public static let x25519SecretKeyLen = 32
    public static let poly1305AuthTagLen = 16
    public static let twoPartyBoxNonceLen = 24
    public static let messageValidForDurationInSeconds = 1209600
    public static let messageExpiryWarningInSeconds = 172800
    public static let maxBackgroundDurationInSeconds = 300
    public static let covernodeWrappingKeyCount = 2
}
