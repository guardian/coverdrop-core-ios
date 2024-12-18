import Foundation
import Sodium

public protocol CoverDropConfig {
    var urlSessionConfig: URLSession { get }
    var envType: EnvType { get }
    var apiBaseUrl: String { get }
    var messageBaseUrl: String { get }
    var cacheEnabled: Bool { get }
    var passphraseWordCount: Int { get }
    var minDurationBetweenBackgroundRunsInSecs: Int { get }
    var maxBackgroundDurationInSeconds: Int { get }
    var numMessagesPerBackgroundRun: Int { get }
    var withSecureDns: Bool { get }
    // TODO: these are for testing only, so we should lets replace them later
    var startWithTestMessages: Bool { get }
    var startWithTestStorage: Bool { get }
    var removeBackgroundSendStateOnStart: Bool { get }
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

    public var urlSessionConfig: URLSession {
        return internalGetConfig().urlSessionConfig
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

    public var startWithTestStorage: Bool {
        return internalGetConfig().startWithTestStorage
    }

    public var startWithTestMessages: Bool {
        return internalGetConfig().startWithTestMessages
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

    public var minDurationBetweenBackgroundRunsInSecs: Int {
        return internalGetConfig().minDurationBetweenBackgroundRunsInSecs
    }

    public var numMessagesPerBackgroundRun: Int {
        return internalGetConfig().numMessagesPerBackgroundRun
    }

    public var removeBackgroundSendStateOnStart: Bool {
        return internalGetConfig().removeBackgroundSendStateOnStart
    }
}

public struct ProdConfig: CoverDropConfig {
    public var envType: EnvType = .prod
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public var urlSessionConfig: URLSession {
        let urlSessionConfig = URLSessionConfiguration.ephemeral
        if withSecureDns {
            if #available(iOS 16.0, *) {
                urlSessionConfig.requiresDNSSECValidation = true
            }
        }
        return URLSession(configuration: urlSessionConfig)
    }

    public let apiBaseUrl = "https://secure-messaging-api.guardianapis.com/v1"
    public let messageBaseUrl = "https://secure-messaging-msg.guardianapis.com"

    public let cacheEnabled = true

    public var startWithTestStorage = false

    public let startWithTestMessages = false

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
    public var removeBackgroundSendStateOnStart = false
}

public struct DemoConfig: CoverDropConfig {
    public var envType: EnvType = .demo
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public var urlSessionConfig: URLSession {
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

    public let cacheEnabled = false

    public var startWithTestStorage = false

    public let startWithTestMessages = false

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
    public var removeBackgroundSendStateOnStart = false
}

public struct AuditConfig: CoverDropConfig {
    public var envType: EnvType = .audit
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public var urlSessionConfig: URLSession {
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

    public let cacheEnabled = true

    public var startWithTestStorage = false

    public let startWithTestMessages = false

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
    public var removeBackgroundSendStateOnStart = false
}

public struct CodeConfig: CoverDropConfig {
    public var envType: EnvType = .code
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public var urlSessionConfig: URLSession {
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

    public let cacheEnabled = false

    public let startWithTestStorage = false

    public var startWithTestMessages: Bool = false

    public let maxBackgroundDurationInSeconds = 10
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
    public var removeBackgroundSendStateOnStart = false
}

public struct DevConfig: CoverDropConfig {
    public var envType: EnvType = .dev
    public var withSecureDns: Bool = false

    public var passphraseWordCount = 3

    public var urlSessionConfig: URLSession {
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

    public var removeBackgroundSendStateOnStart: Bool {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE") {
                return true
            }
        #endif
        return false
    }

    public let maxBackgroundDurationInSeconds = 10
    public var minDurationBetweenBackgroundRunsInSecs = 30
    public var numMessagesPerBackgroundRun = 2
}
