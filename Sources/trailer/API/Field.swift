//
//  Field.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Field: Element {
    let name: String
    var queryText: String { name }
    var fragments: [Fragment] { [] }

    static let id = Field(name: "id")
}
