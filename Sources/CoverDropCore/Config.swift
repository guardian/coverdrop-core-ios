import Foundation
import Sodium

public protocol ConfigProtocol {
    func urlSessionConfig() -> URLSession
    var apiBaseUrl: String { get }
    var messageBaseUrl: String { get }
    var cacheEnabled: Bool { get }
    var passphraseLowWordCount: Int { get }
    var passphraseHighWordCount: Int { get }
    var currentKeysPublishedTime: () -> Date { get }
    func organizationPublicKeys() throws -> [TrustedOrganizationPublicKey]
    var startWithTestStorage: Bool { get }
    func currentTime() -> Date
}

public enum ConfigType: ConfigProtocol {
    case devConfig
    case codeConfig
    case prodConfig

    public func urlSessionConfig() -> URLSession {
        switch self {
        case .devConfig:
            return DevConfig().urlSessionConfig()
        case .codeConfig:
            return CodeConfig().urlSessionConfig()
        case .prodConfig:
            return ProdConfig().urlSessionConfig()
        }
    }

    public var apiBaseUrl: String {
        switch self {
        case .devConfig:
            return DevConfig().apiBaseUrl
        case .codeConfig:
            return CodeConfig().apiBaseUrl
        case .prodConfig:
            return ProdConfig().apiBaseUrl
        }
    }

    public var messageBaseUrl: String {
        switch self {
        case .devConfig:
            return DevConfig().messageBaseUrl
        case .codeConfig:
            return CodeConfig().messageBaseUrl
        case .prodConfig:
            return ProdConfig().messageBaseUrl
        }
    }

    public var cacheEnabled: Bool {
        switch self {
        case .devConfig:
            return DevConfig().cacheEnabled
        case .codeConfig:
            return CodeConfig().cacheEnabled
        case .prodConfig:
            return ProdConfig().cacheEnabled
        }
    }

    public var currentKeysPublishedTime: () -> Date {
        switch self {
        case .devConfig:
            return DevConfig().currentKeysPublishedTime
        case .codeConfig:
            return CodeConfig().currentKeysPublishedTime
        case .prodConfig:
            return ProdConfig().currentKeysPublishedTime
        }
    }

    public func organizationPublicKeys() throws -> [TrustedOrganizationPublicKey] {
        switch self {
        case .devConfig:
            return try DevConfig().organizationPublicKeys()
        case .codeConfig:
            return try CodeConfig().organizationPublicKeys()
        case .prodConfig:
            return try ProdConfig().organizationPublicKeys()
        }
    }

    public var startWithTestStorage: Bool {
        switch self {
        case .devConfig:
            return DevConfig().startWithTestStorage
        case .codeConfig:
            return CodeConfig().startWithTestStorage
        case .prodConfig:
            return ProdConfig().startWithTestStorage
        }
    }

    public var startWithTestMessages: Bool {
        switch self {
        case .devConfig:
            return DevConfig().startWithTestMessages
        case .codeConfig:
            return CodeConfig().startWithTestMessages
        case .prodConfig:
            return ProdConfig().startWithTestMessages
        }
    }

    public func currentTime() -> Date {
        switch self {
        case .devConfig:
            return DevConfig().currentTime()
        case .codeConfig:
            return CodeConfig().currentTime()
        case .prodConfig:
            return ProdConfig().currentTime()
        }
    }

    public var maxBackgroundDurationInSeconds: Int {
        switch self {
        case .devConfig:
            return DevConfig().maxBackgroundDurationInSeconds
        case .codeConfig:
            return CodeConfig().maxBackgroundDurationInSeconds
        case .prodConfig:
            return ProdConfig().maxBackgroundDurationInSeconds
        }
    }

    public var passphraseLowWordCount: Int {
        switch self {
        case .devConfig:
            return DevConfig().passphraseLowWordCount
        case .codeConfig:
            return CodeConfig().passphraseLowWordCount
        case .prodConfig:
            return ProdConfig().passphraseLowWordCount
        }
    }

    public var passphraseHighWordCount: Int {
        switch self {
        case .devConfig:
            return DevConfig().passphraseHighWordCount
        case .codeConfig:
            return CodeConfig().passphraseHighWordCount
        case .prodConfig:
            return ProdConfig().passphraseHighWordCount
        }
    }
}

public struct ProdConfig: ConfigProtocol {
    public var passphraseLowWordCount = 4
    public var passphraseHighWordCount = 10

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        return URLSession(configuration: urlSessionConfig)
    }

    public let apiBaseUrl = "https://coverdrop-api.code.dev-gutools.co.uk/v1"
    public let messageBaseUrl = "https://secure-messaging.code.dev-guardianapis.com"

    // This supplies a date function, which is used to determine the current date
    // This is required as our mock keys data cannot be guarenteed to be valid
    // (because the expiry times of tokens are static)
    // So MockDate.now returns a date in the past at the current date
    // This is only used for UI and Unit tests that require valid keys
    public let currentKeysPublishedTime: () -> Date = {
        var dateFunc = Date()
        return dateFunc
    }

    public func organizationPublicKeys() throws -> [TrustedOrganizationPublicKey] {
        let resourcePaths: [String] = Bundle.module.paths(forResourcesOfType: "json", inDirectory: "organization_keys")

        let keys: [TrustedOrganizationPublicKey] = try resourcePaths.compactMap { fullPath in
            // As `Bundle.module.paths` returns the full path, we just want to get the filename
            let fileName = URL(fileURLWithPath: fullPath).lastPathComponent
            let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
            let resourceUrlOption = Bundle.module.url(forResource: fileNameWithoutExtension, withExtension: ".json", subdirectory: "organization_keys")
            if let resourceUrl = resourceUrlOption {
                let data = try Data(contentsOf: resourceUrl)
                let keyData = try JSONDecoder().decode(UnverifiedSignedPublicSigningKeyData.self, from: data)

                return SelfSignedPublicSigningKey<TrustedOrganization>.init(key: Sign.KeyPair.PublicKey(keyData.key.bytes), certificate: Signature<TrustedOrganization>.fromBytes(bytes: keyData.certificate.bytes), notValidAfter: keyData.notValidAfter.date, now: Date.now)
            }
            return nil
        }

        return keys
    }

    public let cacheEnabled = true

    public var startWithTestStorage = false

    public let startWithTestMessages = false

    public func currentTime() -> Date {
        return Date()
    }

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
}

public struct CodeConfig: ConfigProtocol {
    public var passphraseLowWordCount = 4
    public var passphraseHighWordCount = 10

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        return URLSession(configuration: urlSessionConfig)
    }

    public let apiBaseUrl = "https://coverdrop-api.code.dev-gutools.co.uk/v1"
    public let messageBaseUrl = "https://secure-messaging.code.dev-guardianapis.com"

    // This supplies a date function, which is used to determine the current date
    // This is required as our mock keys data cannot be guarenteed to be valid
    // (because the expiry times of tokens are static)
    // So MockDate.now returns a date in the past at the current date
    // This is only used for UI and Unit tests that require valid keys
    public let currentKeysPublishedTime: () -> Date = {
        MockDate.currentTime()
    }

    public func organizationPublicKeys() throws -> [TrustedOrganizationPublicKey] {
        return try ProdConfig().organizationPublicKeys()
    }

    public let cacheEnabled = false

    public let startWithTestStorage = false

    public var startWithTestMessages: Bool = false

    public func currentTime() -> Date {
        return Date()
    }

    public let maxBackgroundDurationInSeconds = 10
}

public struct DevConfig: ConfigProtocol {
    public var passphraseLowWordCount = 4
    public var passphraseHighWordCount = 10

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        URLProtocolMock.mockURLs = MockUrlData.getMockUrlData()
        urlSessionConfig.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: urlSessionConfig)
    }

    public let apiBaseUrl = "http://localhost:3000/v1"
    public let messageBaseUrl = "http://localhost:7676"

    // This supplies a date function, which is used to determine the current date
    // This is required as our mock keys data cannot be guarenteed to be valid
    // (because the expiry times of tokens are static)
    // So MockDate.now returns a date in the past at the current date
    // This is only used for UI and Unit tests that require valid keys
    public let currentKeysPublishedTime: () -> Date = {
        MockDate.currentTime()
    }

    public func organizationPublicKeys() throws -> [TrustedOrganizationPublicKey] {
        return try ProdConfig().organizationPublicKeys()
    }

    public let cacheEnabled = false

    public let startWithTestStorage = true

    public var startWithTestMessages: Bool {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE") {
                if ProcessInfo.processInfo.arguments.contains("START_WITH_MESSAGES") {
                    return true
                }
            }
        #endif
        return false
    }

    public func currentTime() -> Date {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE") {
                if ProcessInfo.processInfo.arguments.contains("EXPIRED_MESSAGES_SCENARIO") {
                    let keysDate = MockDate.currentTime()
                    return Date(timeInterval: TimeInterval(1 - (60 * 60 * 24 * 13)), since: keysDate)
                } else {
                    return Date()
                }
            }
        #endif
        return Date()
    }

    public let maxBackgroundDurationInSeconds = 10
}

public enum ApplicationConfig {
    public static var config: ConfigType {
        var config = ConfigType.prodConfig
        #if DEBUG
            let userDefaults = UserDefaults.standard
            var useDevBackend = false
            if userDefaults.value(forKey: "useDevBackend") != nil {
                useDevBackend = userDefaults.bool(forKey: "useDevBackend")
            }
            if useDevBackend {
                config = ConfigType.devConfig
            } else {
                config = ConfigType.codeConfig
            }
        #endif
        return config
    }
}
