//
//  ItemState.swift
//  trailer
//
//  Created by Paul Tsochantaris on 28/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum ItemState: String, Codable {
    case open, closed, merged
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "open": self = .open
        case "closed": self = .closed
        case "merged": self = .merged
        default: return nil
        }
    }
}
