import Foundation
import Lista

struct Notifications {
    struct Notification {
        let title: String?
        let subtitle: String?
        let details: String?
        let relatedDate: Date

        static let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            return f
        }()

        func go() {
            if let title, title.hasItems {
                let d = Notification.formatter.string(from: relatedDate)
                log("[!\(d) \(title)!]")
            }
            if let subtitle, subtitle.hasItems {
                log("[*\(subtitle)*]")
            }
            if let details, details.hasItems {
                log(details)
            }
            log()
        }
    }

    private static let notificationQueue = Lista<Notification>()

    static func notify(title: String?, subtitle: String?, details: String?, relatedDate: Date) {
        let n = Notification(title: title, subtitle: subtitle, details: details, relatedDate: relatedDate)
        notificationQueue.append(n)
    }

    static func processQueue() {
        for n in notificationQueue.sorted(by: { $0.relatedDate < $1.relatedDate }) {
            n.go()
        }
        notificationQueue.removeAll()
    }
}
