// DO NOT EDIT! This file is auto-generated from Rust code using the following command:
// `cargo run --bin admin generate-mobile-constants-files`.
//
// The Rust code is here: common/src/protocol/constants.rs

// swiftlint:disable identifier_name 
public enum Constants {
    public static let journalistProvisioningKeyValidDurationSeconds = 14515200
    public static let journalistIdKeyValidDurationSeconds = 4838400
    public static let journalistMsgKeyValidDurationSeconds = 604800
    public static let covernodeProvisioningKeyValidDurationSeconds = 14515200
    public static let covernodeIdKeyValidDurationSeconds = 2419200
    public static let covernodeMsgKeyValidDurationSeconds = 1209600
    public static let userToCovernodeEncryptedMessageLen = 773
    public static let userToCovernodeMessageLen = 597
    public static let userToJournalistEncryptedMessageLen = 593
    public static let userToJournalistMessageLen = 545
    public static let journalistToCovernodeEncryptedMessageLen = 730
    public static let journalistToCovernodeMessageLen = 554
    public static let journalistToUserEncryptedMessageLen = 553
    public static let journalistToUserMessageLen = 513
    public static let messagePaddingLen = 512
    public static let recipientTagLen = 4
    public static let realOrCoverByteLen = 1
    public static let x25519PublicKeyLen = 32
    public static let x25519SecretKeyLen = 32
    public static let poly1305AuthTagLen = 16
    public static let twoPartyBoxNonceLen = 24
    public static let messageValidForDurationInSeconds = 1209600
    public static let messageExpiryWarningInSeconds = 172800
    public static let maxBackgroundDurationInSeconds = 300
    public static let clientDeadDropCacheTtlSeconds = 1209600
    public static let localCacheDurationBetweenDownloadsSeconds = 3600
    public static let covernodeWrappingKeyCount = 2
}
 // swiftlint:enable identifier_name
