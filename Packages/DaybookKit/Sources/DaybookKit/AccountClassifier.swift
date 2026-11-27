import Foundation

/// Decides which of the three supported accounts a calendar source belongs to.
/// Works on plain values so it can be unit tested without EventKit.
public enum AccountClassifier {
    public enum SourceKind: Sendable {
        case local, exchange, calDAV, mobileMe, subscribed, birthdays, other
    }

    /// Returns nil for sources Daybook does not show (local, birthdays, unknown accounts).
    public static func classify(kind: SourceKind, sourceTitle: String) -> AccountKind? {
        let t = sourceTitle.lowercased()
        switch kind {
        case .exchange:
            return .outlook
        case .mobileMe:
            return .iCloud
        case .calDAV:
            if t.contains("icloud") { return .iCloud }
            if t.contains("gmail") || t.contains("google") { return .google }
            if t.contains("outlook") || t.contains("hotmail") || t.contains("live.com") || t.contains("office") { return .outlook }
            return nil
        case .subscribed:
            // Subscribed calendars (e.g. public holidays) are synced with iCloud on iOS.
            return .iCloud
        case .local, .birthdays, .other:
            return nil
        }
    }
}
