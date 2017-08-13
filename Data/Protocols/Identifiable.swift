//
//  Identifiable.swift
//  trailer
//
//  Created by Paul Tsochantaris on 28/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol Identifiable: Codable {
    var id: String { get set }
    var elementType: String { get set }
    var syncState: SyncState { get set }
}

extension Identifiable {
    static var typeName: String {
        return String(describing: type(of: self)).components(separatedBy: ".").first!
    }
    var typeName: String {
        return String(describing: type(of: self)).components(separatedBy: ".").first!
    }
}
