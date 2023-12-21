import Foundation
import OSLog

public enum Debug {
    public static func println(_ message: Any) {
        #if DEBUG
            let logger = Logger(subsystem: "com.theguardian.reference",
                                category: "Debug")
            print(message)
            logger.log("\(String(describing: message))")
        #endif
    }
}
