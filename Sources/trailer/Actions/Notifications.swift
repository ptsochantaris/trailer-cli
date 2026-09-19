import Foundation
import Lista

enum Notifications {
    struct Notification {
        let title: String?
        let subtitle: String?
        let details: String?
        let relatedDate: Date

        /// Short local date and time, e.g. `17/03/2024, 09:41`. Also used for the label on check
        /// runs, which arrive from the API without a context string.
        static let timestampStyle = Date.FormatStyle(date: .numeric, time: .shortened)

        func go() {
            if let title, !title.isEmpty {
                let d = relatedDate.formatted(Notification.timestampStyle)
                log("[!\(d) \(title)!]")
            }
            if let subtitle, !subtitle.isEmpty {
                log("[*\(subtitle)*]")
            }
            if let details, !details.isEmpty {
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
