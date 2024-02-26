import Foundation
import Sodium

public protocol CoverDropConfig {
    func urlSessionConfig() -> URLSession
    var envType: EnvType { get }
    var apiBaseUrl: String { get }
    var messageBaseUrl: String { get }
    var cacheEnabled: Bool { get }
    var passphraseWordCount: Int { get }
    var currentKeysPublishedTime: () -> Date { get }
    var startWithTestMessages: Bool { get }
    var startWithTestStorage: Bool { get }
    var maxBackgroundDurationInSeconds: Int { get }
    var withSecureDns: Bool { get }
    func currentTime() -> Date
}

public enum EnvType {
    case dev, code, prod, audit, demo
}

public enum StaticConfig: CoverDropConfig {
    case devConfig
    case codeConfig
    case prodConfig
    case auditConfig
    case demoConfig

    private func internalGetConfig() -> CoverDropConfig {
        switch self {
        case .devConfig:
            return DevConfig()
        case .codeConfig:
            return CodeConfig()
        case .prodConfig:
            return ProdConfig()
        case .auditConfig:
            return AuditConfig()
        case .demoConfig:
            return DemoConfig()
        }
    }

    public func urlSessionConfig() -> URLSession {
        return internalGetConfig().urlSessionConfig()
    }

    public var apiBaseUrl: String {
        return internalGetConfig().apiBaseUrl
    }

    public var messageBaseUrl: String {
        return internalGetConfig().messageBaseUrl
    }

    public var cacheEnabled: Bool {
        return internalGetConfig().cacheEnabled
    }

    public var currentKeysPublishedTime: () -> Date {
        return internalGetConfig().currentKeysPublishedTime
    }

    public var startWithTestStorage: Bool {
        return internalGetConfig().startWithTestStorage
    }

    public var startWithTestMessages: Bool {
        return internalGetConfig().startWithTestMessages
    }

    public func currentTime() -> Date {
        return internalGetConfig().currentTime()
    }

    public var maxBackgroundDurationInSeconds: Int {
        return internalGetConfig().maxBackgroundDurationInSeconds
    }

    public var passphraseWordCount: Int {
        return internalGetConfig().passphraseWordCount
    }

    public var withSecureDns: Bool {
        return internalGetConfig().withSecureDns
    }

    public var envType: EnvType {
        return internalGetConfig().envType
    }
}

public struct ProdConfig: CoverDropConfig {
    public var envType: EnvType = .prod
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        if withSecureDns {
            if #available(iOS 16.0, *) {
                urlSessionConfig.requiresDNSSECValidation = true
            }
        }
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

    public let cacheEnabled = true

    public var startWithTestStorage = false

    public let startWithTestMessages = false

    public func currentTime() -> Date {
        return Date()
    }

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
}

public struct DemoConfig: CoverDropConfig {
    public var envType: EnvType = .demo
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        if withSecureDns {
            if #available(iOS 16.0, *) {
                urlSessionConfig.requiresDNSSECValidation = true
            }
        }
        return URLSession(configuration: urlSessionConfig)
    }

    public let apiBaseUrl = "https://secure-messaging-api-demo.guardianapis.com/v1"
    public let messageBaseUrl = "https://secure-messaging-msg-demo.guardianapis.com"

    // This supplies a date function, which is used to determine the current date
    // This is required as our mock keys data cannot be guarenteed to be valid
    // (because the expiry times of tokens are static)
    // So MockDate.now returns a date in the past at the current date
    // This is only used for UI and Unit tests that require valid keys
    public let currentKeysPublishedTime: () -> Date = {
        var dateFunc = Date()
        return dateFunc
    }

    public let cacheEnabled = false

    public var startWithTestStorage = false

    public let startWithTestMessages = false

    public func currentTime() -> Date {
        return Date()
    }

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
}

public struct AuditConfig: CoverDropConfig {
    public var envType: EnvType = .audit
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        if withSecureDns {
            if #available(iOS 16.0, *) {
                urlSessionConfig.requiresDNSSECValidation = true
            }
        }
        return URLSession(configuration: urlSessionConfig)
    }

    public let apiBaseUrl = "https://secure-messaging-api-audit.guardianapis.com/v1"
    public let messageBaseUrl = "https://secure-messaging-msg-audit.guardianapis.com"

    public let currentKeysPublishedTime: () -> Date = {
        var dateFunc = Date()
        return dateFunc
    }

    public let cacheEnabled = true

    public var startWithTestStorage = false

    public let startWithTestMessages = false

    public func currentTime() -> Date {
        return Date()
    }

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
}

public struct CodeConfig: CoverDropConfig {
    public var envType: EnvType = .code
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        if withSecureDns {
            if #available(iOS 16.0, *) {
                urlSessionConfig.requiresDNSSECValidation = true
            }
        }
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

    public let cacheEnabled = false

    public let startWithTestStorage = false

    public var startWithTestMessages: Bool = false

    public func currentTime() -> Date {
        return Date()
    }

    public let maxBackgroundDurationInSeconds = 10
}

public struct DevConfig: CoverDropConfig {
    public var envType: EnvType = .dev
    public var withSecureDns: Bool = false

    public var passphraseWordCount = 3

    public func urlSessionConfig() -> URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        if withSecureDns {
            if #available(iOS 16.0, *) {
                urlSessionConfig.requiresDNSSECValidation = true
            }
        }
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

    public let cacheEnabled = false

    public var startWithTestStorage: Bool {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE") {
                if ProcessInfo.processInfo.arguments.contains("START_WITH_STORAGE") {
                    return true
                }
            }
        #endif
        return false
    }

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
