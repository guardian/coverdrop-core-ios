import Foundation

/// All testing flags that e.g. UI tests might pas to our program to change its default behavior
public enum TestingFlag: String {
    case startWithEmptyStorage = "START_WITH_EMPTY_STORAGE"
    case startWithNonEmptyStorage = "START_WITH_NON_EMPTY_STORAGE"
    case removeBackgroundSendStateOnStart = "REMOVE_BACKGROUND_STATE"
    case disableAnimations = "DISABLE_ANIMATIONS"
    case mockedDataEmptyKeysData = "EMPTY_KEYS_DATA"
    case mockedDataMultipleJournalists = "MULTIPLE_JOURNALIST_SCENARIO"
    case mockedDataNoDefaultJournalist = "MOCKED_DATA_NO_DEFAULT_JOURNALIST"
    case mockedDataStatusUnavailable = "STATUS_UNAVAILABLE"
    case mockedDataExpiredMessagesScenario = "EXPIRED_MESSAGES_SCENARIO"
}

public class TestingBridge {
    /// Returns `true` if the given testing flag has been enabled for the reference application
    public static func isEnabled(_ flag: TestingFlag, processInfo: ProcessInfo? = nil) -> Bool {
        let processInfo = processInfo ?? ProcessInfo.processInfo
        return processInfo.arguments.contains(flag.rawValue)
    }

    public static func setTestingFlags(launchArguments: inout [String], flags: [TestingFlag]) {
        for flag in flags {
            launchArguments.append(flag.rawValue)
        }
    }

    /// Returns `true` if the reference app should enable mocked API resonses
    public static func isMockedDataEnabled() -> Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
}
