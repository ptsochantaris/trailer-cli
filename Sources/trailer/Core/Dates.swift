import Foundation

enum GHDateFormatter {
    /// GitHub timestamps are ISO-8601 in UTC, e.g. `2024-03-17T09:41:00Z`.
    private static let parseStrategy = Date.ISO8601FormatStyle(timeZone: .gmt)

    static func parseGH8601(_ iso8601: String?) -> Date? {
        guard let iso8601 else { return nil }
        return try? parseStrategy.parse(iso8601)
    }
}

/// Renders a date as a relative phrase, e.g. `Created 2 months ago`. One implementation across
/// macOS, Linux and Windows, since `Date.RelativeFormatStyle` is part of swift-foundation.
func agoFormat(prefix: String, since: Date?) -> String {
    guard let since, since != .distantPast else {
        return "\(prefix)(unknown)"
    }

    if -since.timeIntervalSinceNow < 10 {
        return prefix.isEmpty ? "Just now" : "\(prefix)just now"
    }

    let duration = since.formatted(.relative(presentation: .numeric, unitsStyle: .wide))
    return "\(prefix)\(duration)"
}
