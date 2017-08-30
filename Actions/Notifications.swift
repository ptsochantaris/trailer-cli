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

        func go() {
            if let title = title, !title.isEmpty {
                log("[!\(title)!]")
            }
            if let subtitle = subtitle, !subtitle.isEmpty {
                log("[$\(subtitle)!]")
            }
            if let details = details, !details.isEmpty {
                log(details)
            }
            log()
        }
    }

    private static var notificationQueue = [Notification]()

    static func notify(title: String?, subtitle: String?, details: String?) {
        let n = Notification(title: title, subtitle: subtitle, details: details)
        notificationQueue.append(n)
    }

    static func processQueue() {
        for n in notificationQueue {
            n.go()
        }
        notificationQueue.removeAll()
    }
}
