//
//  Closeable.swift
//  trailer
//
//  Created by Paul Tsochantaris on 29/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol Closeable {
    var shouldAnnounceClosure: Bool { get }
    func announceClosure()
}
