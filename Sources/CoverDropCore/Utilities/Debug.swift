import Foundation

public enum Debug {
    static func println(_ message: Any) {
        #if DEBUG
        print(message)
        #endif
    }
}
