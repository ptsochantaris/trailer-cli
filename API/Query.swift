//
//  Query.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation
import Dispatch

struct Parent {
	let item: Identifiable
	let field: String
	init?(item: Identifiable?, field: String?) {
		self.field = field ?? "NOFIELD"
		if let i = item {
			self.item = i
		} else {
			return nil
		}
	}
}

struct Query {
	private static let processingQueue: OperationQueue = {
		let o = OperationQueue()
		o.maxConcurrentOperationCount = 1
		o.qualityOfService = .userInitiated
		return o
	}()

	private static let urlSession: URLSession = {
		let c = URLSessionConfiguration.default
		return URLSession(configuration: c, delegate: nil, delegateQueue: processingQueue)
	}()

	let name: String

	private let rootElement: Ingesting
	private let parent: Parent?
	private let subQuery: Bool

	init(name: String, rootElement: Ingesting, parent: Parent? = nil, subQuery: Bool = false) {
		self.rootElement = rootElement
		self.parent = parent
		self.name = name
		self.subQuery = subQuery
	}

	var queryText: String {
		var fragments = [Fragment]()
		for f in rootElement.fragments {
			if !fragments.contains(where: { $0.name == f.name }) {
				fragments.append(f)
			}
		}

		var text = ""
		for f in fragments {
			text.append(f.declaration + " ")
		}
		var rootQuery = rootElement.queryText
		if let parentItem = parent?.item {
			rootQuery = "node(id: \"\(parentItem.id)\") { ... on \(parentItem.elementType) { " + rootQuery + " } }"
		}
		return text + "{ " + rootQuery + " rateLimit { limit cost remaining resetAt nodeCount } }"
	}
	func runAndWait() -> Bool {
		let g = DispatchGroup()
		g.enter()
		var s = false
		run { success in
			s = success
			g.leave()
		}
		g.wait()
		return s
	}

	func run(shouldRetry: Bool = true, completion: @escaping (Bool)->Void) {

		func errorCompletion(_ message: String) {
			if shouldRetry {
				log(level: .verbose, "[*\(name)*] \(message)")
				log(level: .verbose, "[*\(name)*] Retrying")
				run(shouldRetry: false, completion: completion)
			} else {
				log("[*\(name)*] \(message)")
				completion(false)
			}
		}

		func branchCompletion(_ extraQueries: [Query]) {
			if extraQueries.count > 0 {
				log(level: .debug, "[*\(name)*] Needs more page data")
				let group = DispatchGroup()
				var success = true
				for e in extraQueries {
					group.enter()
					e.run { s in
						if !s { success = false }
						group.leave()
					}
				}
				group.notify(queue: DispatchQueue.global(), execute: {
					completion(success)
				})
			} else {
				if !subQuery {
					log(level: .verbose, "[*\(name)*] Completed successfully")
				}
				completion(true)
			}
		}

		func extractNodeData(from json: [AnyHashable : Any]) -> [AnyHashable :  Any]? {
			if let data = json["data"] as? [AnyHashable : Any] {
				if parent == nil {
					return data
				} else {
					return data["node"] as? [AnyHashable : Any]
				}
			}
			return nil
		}

		func extractRateLimit(from json: [AnyHashable : Any]) -> [AnyHashable :  Any]? {
			if let data = json["data"] as? [AnyHashable : Any] {
				return data["rateLimit"] as? [AnyHashable : Any]
			}
			return nil
		}

		if shouldRetry && !subQuery {
			log("[*\(name)*] Fetching")
		}
		let Q = queryText
		log(level: .debug, "[*\(name)*] \(Q)")

		var r = URLRequest(url: config.server)
		r.setValue("bearer \(config.token)", forHTTPHeaderField: "Authorization")
		r.httpMethod = "POST"
		r.httpBody = try! JSONEncoder().encode(["query": Q])

		Query.urlSession.dataTask(with: r) { info, response, error in
			if let info = info, let json = (try? JSONSerialization.jsonObject(with: info, options: [])) as? [AnyHashable : Any] {

				if let data = extractNodeData(from: json) {

					log(level: .verbose, "[*\(self.name)*] Processing page of data")

					if let rateLimit = extractRateLimit(from: json), let cost = rateLimit["cost"] as? Int, let remaining = rateLimit["remaining"] as? Int, let nodeCount = rateLimit["nodeCount"] as? Int {
						config.totalQueryCosts += cost
						config.totalApiRemaining = min(config.totalApiRemaining, remaining)
						log(level: .verbose, "[*\(self.name)*] Cost: [!\(cost)!], Remaining: [!\(remaining)!] - Node Count: [!\(nodeCount)!]")
					}

					let r = self.rootElement
					if let topData = data[r.name] {
						let extraQueries = r.ingest(query: self, pageData: topData, parent: self.parent, level: 0)
						branchCompletion(extraQueries)
					} else {
						errorCompletion("No data in JSON")
					}

				} else {
					let msg = (json["errors"] as? [[AnyHashable:Any]])?.first?["message"] as? String ?? "Unspecified server error: \(json)"
					errorCompletion("Failed with error: '\(msg)'")
				}

			} else {

				if let error = error {
					errorCompletion("Network error: \(error.localizedDescription)")
				} else {
					errorCompletion("No JSON in response")
				}
			}
		}.resume()
	}
}
