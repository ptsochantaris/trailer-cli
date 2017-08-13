//
//  Fragment.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Fragment: Ingesting {
	var name: String

	var queryText: String {
		return "... \(name)"
	}

	var declaration: String {
		return "fragment \(name) on \(type) { __typename " + fields.map({$0.queryText}).joined(separator: " ") + " }"
	}

	var fragments: [Fragment] {
		var res = [self]
		for f in fields {
			res.append(contentsOf: f.fragments)
		}
		return res
	}

	private var fields: [Element]
	private let type: String

	init(name: String, on type: String, fields: [Element]) {
		self.name = name
		self.type = type
		self.fields = fields
	}
	
	func ingest(query: Query, pageData: Any, parent: Parent?, level: Int) -> [Query] {
		log(level: .debug, indent: level, "Ingesting fragment \(name)")
		guard let hash = pageData as? [AnyHashable : Any] else { return [] }

		var extraQueries = [Query]()
		for field in fields {
			if let fieldData = hash[field.name], let field = field as? Ingesting {
				let p = Parent(item: parent?.item, field: field.name)
				let newQueries = field.ingest(query: query, pageData: fieldData, parent: p, level: level+1)
				extraQueries.append(contentsOf: newQueries)
			}
		}
		return extraQueries
	}
}
