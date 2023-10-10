import Foundation

/// Allows throwing an Error via a String
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
