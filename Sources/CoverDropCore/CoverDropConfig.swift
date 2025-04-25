import Foundation
import Sodium

public protocol CoverDropConfig {
    var envType: EnvType { get }
    var apiBaseUrl: String { get }
    var messageBaseUrl: String { get }
    var cacheEnabled: Bool { get }
    var passphraseWordCount: Int { get }
    // This is the duration between background message sending
    var minDurationBetweenBackgroundRunsInSecs: Int { get }
    // This is the longest duration you can have the app in the background before you are logged out
    var maxBackgroundDurationInSeconds: Int { get }
    var numMessagesPerBackgroundRun: Int { get }
    var withSecureDns: Bool { get }
}

public enum EnvType {
    case dev, code, prod, staging, demo
}

public enum StaticConfig: CoverDropConfig {
    case devConfig
    case codeConfig
    case prodConfig
    case stagingConfig
    case demoConfig

    private func internalGetConfig() -> CoverDropConfig {
        switch self {
        case .devConfig:
            return DevConfig()
        case .codeConfig:
            return CodeConfig()
        case .prodConfig:
            return ProdConfig()
        case .stagingConfig:
            return StagingConfig()
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

public struct StagingConfig: CoverDropConfig {
    public var envType: EnvType = .staging
    public var withSecureDns: Bool = true

    public var passphraseWordCount = 3

    public let apiBaseUrl = "https://secure-messaging-api-staging.guardianapis.com/v1"
    public let messageBaseUrl = "https://secure-messaging-msg-staging.guardianapis.com"

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

    // The maxBackgroundDurationInSeconds is longer that minDurationBetweenBackgroundRunsInSecs
    // so we can test the background sending when foregrounding the app without the auto logout being triggered
    public let maxBackgroundDurationInSeconds = 20
    public var minDurationBetweenBackgroundRunsInSecs = 10
    public var numMessagesPerBackgroundRun = 2
}
