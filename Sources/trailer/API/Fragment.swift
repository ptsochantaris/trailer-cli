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
		return "fragment \(name) on \(type) { __typename " + elements.map({$0.queryText}).joined(separator: " ") + " }"
	}

	var fragments: [Fragment] {
		var res = [self]
		for e in elements {
			res.append(contentsOf: e.fragments)
		}
		return res
	}

	private var elements: [Element]
	private let type: String

	init(name: String, on type: String, elements: [Element]) {
		self.name = name
		self.type = type
		self.elements = elements
	}

	mutating func addField(_ extraField: Element) {
		elements.append(extraField)
	}
	
	func ingest(query: Query, pageData: Any, parent: Parent?, level: Int) -> [Query] {
		log(level: .debug, indent: level, "Ingesting fragment \(name)")
		guard let hash = pageData as? [AnyHashable : Any] else { return [] }

		var extraQueries = [Query]()
		for element in elements {
			if let elementData = hash[element.name], let element = element as? Ingesting {
				let p = Parent(item: parent?.item, field: element.name)
				let newQueries = element.ingest(query: query, pageData: elementData, parent: p, level: level+1)
				extraQueries.append(contentsOf: newQueries)
			}
		}
		return extraQueries
	}
}
