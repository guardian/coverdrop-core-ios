import Foundation
import Sodium

public protocol CoverDropConfig {
    var envType: EnvType { get }
    var apiBaseUrl: String { get }
    var messageBaseUrl: String { get }
    var cacheEnabled: Bool { get }
    var passphraseWordCount: Int { get }
    var minDurationBetweenBackgroundRunsInSecs: Int { get }
    var maxBackgroundDurationInSeconds: Int { get }
    var numMessagesPerBackgroundRun: Int { get }
    var withSecureDns: Bool { get }
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

    public var apiBaseUrl: String {
        return internalGetConfig().apiBaseUrl
    }

    public var messageBaseUrl: String {
        return internalGetConfig().messageBaseUrl
    }

    public var cacheEnabled: Bool {
        return internalGetConfig().cacheEnabled
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
}

public struct ProdConfig: CoverDropConfig {
    public var envType: EnvType = .prod
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public let apiBaseUrl = "https://secure-messaging-api.guardianapis.com/v1"
    public let messageBaseUrl = "https://secure-messaging-msg.guardianapis.com"

    public let cacheEnabled = true

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
}

public struct DemoConfig: CoverDropConfig {
    public var envType: EnvType = .demo
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public let apiBaseUrl = "https://secure-messaging-api-demo.guardianapis.com/v1"
    public let messageBaseUrl = "https://secure-messaging-msg-demo.guardianapis.com"

    public let cacheEnabled = false

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
    public var removeBackgroundSendStateOnStart = false
}

public struct AuditConfig: CoverDropConfig {
    public var envType: EnvType = .audit
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public let apiBaseUrl = "https://secure-messaging-api-audit.guardianapis.com/v1"
    public let messageBaseUrl = "https://secure-messaging-msg-audit.guardianapis.com"

    public let cacheEnabled = true

    public let maxBackgroundDurationInSeconds = Constants.maxBackgroundDurationInSeconds
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
    public var removeBackgroundSendStateOnStart = false
}

public struct CodeConfig: CoverDropConfig {
    public var envType: EnvType = .code
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public let apiBaseUrl = "https://coverdrop-api.code.dev-gutools.co.uk/v1"
    public let messageBaseUrl = "https://secure-messaging.code.dev-guardianapis.com"

    public let cacheEnabled = false

    public let maxBackgroundDurationInSeconds = 10
    public var minDurationBetweenBackgroundRunsInSecs = 60 * 60
    public var numMessagesPerBackgroundRun = 2
    public var removeBackgroundSendStateOnStart = false
}

public struct DevConfig: CoverDropConfig {
    public var envType: EnvType = .dev
    public var withSecureDns: Bool = false

    public var passphraseWordCount = 3

    public let apiBaseUrl = "http://localhost:3000/v1"
    public let messageBaseUrl = "http://localhost:7676"

    public let cacheEnabled = false

    public let maxBackgroundDurationInSeconds = 10
    public var minDurationBetweenBackgroundRunsInSecs = 30
    public var numMessagesPerBackgroundRun = 2
}
