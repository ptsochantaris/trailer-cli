//
//  Element.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol Element {
	var name: String { get }
	var queryText: String { get }
	var fragments: [Fragment] { get }
}
