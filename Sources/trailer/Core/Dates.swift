import Foundation

enum GHDateFormatter {
    private static let formatter: DateFormatter = {
        let d = DateFormatter()
        d.timeZone = TimeZone(secondsFromGMT: 0)
        d.locale = Locale(identifier: "en_US_POSIX")
        d.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return d
    }()

    static func parseGH8601(_ iso8601: String?) -> Date? {
        guard let iso8601 else { return nil }
        return formatter.date(from: iso8601)
    }
}

#if os(macOS)
    private let agoFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.year, .month, .weekOfMonth, .day, .hour, .minute, .second]
        f.unitsStyle = .full
        f.maximumUnitCount = 2
        return f
    }()

    func agoFormat(prefix: String, since: Date?) -> String {
        guard let since, since != .distantPast else {
            return "\(prefix)(unknown)"
        }

        let interval = -since.timeIntervalSinceNow
        if interval < 10.0 {
            if prefix.isEmpty {
                return "Just now"
            } else {
                return "\(prefix)just now"
            }
        } else {
            let duration = agoFormatter.string(from: since, to: Date()) ?? "unknown time"
            return "\(prefix)\(duration) ago"
        }
    }

#elseif os(Linux) || os(Windows)
    private let agoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .full
        f.dateStyle = .full
        return f
    }()

    func agoFormat(prefix: String, since: Date?) -> String {
        guard let since, since != .distantPast else {
            return "\(prefix)(unknown)"
        }

        let interval = -since.timeIntervalSinceNow
        if interval < 60.0 {
            if prefix.isEmpty {
                return "Just now"
            } else {
                return "\(prefix)just now"
            }
        } else {
            let time = agoFormatter.string(from: since)
            return "\(prefix)\(time)"
        }
    }
#endif
