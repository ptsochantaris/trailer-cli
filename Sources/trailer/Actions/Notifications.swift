//
//  Notifications.swift
//  trailer
//
//  Created by Paul Tsochantaris on 30/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

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
            if let title = title, title.hasItems {
                let d = Notification.formatter.string(from: relatedDate)
                log("[!\(d) \(title)!]")
            }
            if let subtitle = subtitle, subtitle.hasItems {
                log("[*\(subtitle)*]")
            }
            if let details = details, details.hasItems {
                log(details)
            }
            log()
        }
    }

    private static var notificationQueue = [Notification]()

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
