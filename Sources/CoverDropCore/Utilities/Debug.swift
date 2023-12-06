import Foundation

public enum Debug {
    public static func println(_ message: Any) {
        #if DEBUG
        print(message)
        #endif
    }
}
