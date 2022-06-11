//
//  Announceable.swift
//  trailer
//
//  Created by Paul Tsochantaris on 28/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol Announceable: DetailPrinter {
    func announceIfNeeded(notificationMode: NotificationMode)
}
