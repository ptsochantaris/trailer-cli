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
	var queryText: String { return name }
	var fragments: [Fragment] { return [] }
}
