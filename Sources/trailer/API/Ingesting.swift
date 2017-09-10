//
//  Ingesting.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol Ingesting: Element {
	func ingest(query: Query, pageData: Any, parent: Parent?, level: Int) -> [Query]
}

