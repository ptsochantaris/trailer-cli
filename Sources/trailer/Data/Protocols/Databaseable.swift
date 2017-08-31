//
//  Databaseable.swift
//  trailer
//
//  Created by Paul Tsochantaris on 28/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol Databaseable {
    static func saveAll(using encoder: JSONEncoder)
    static func loadAll(using decoder: JSONDecoder)
    static func processAnnouncements(notificationMode: NotificationMode)
    static func purgeUntouchedItems()
    static func purgeStaleRelationships()
}
