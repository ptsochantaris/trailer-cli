//
//  Query.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

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
	private static let urlSession: URLSession = {
		let c = URLSessionConfiguration.default
		c.httpMaximumConnectionsPerHost = 1
		c.httpShouldUsePipelining = true
		c.httpAdditionalHeaders = config.httpHeaders
		return URLSession(configuration: c, delegate: nil, delegateQueue: nil)
	}()
    
    static func getData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(macOS 12.0, *) {
            return try await urlSession.data(for: request)
        } else {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                urlSession.dataTask(with: request) { data, response, error in
                    if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: error ?? NSError(domain: "build.bru.trailer-cli.network", code: 92, userInfo: [NSLocalizedDescriptionKey: "No data or error from server"]))
                    }
                }
            }
        }
    }
    
    static func getData(from url: URL) async throws -> (Data, URLResponse) {
        let req = URLRequest(url: url)
        return try await getData(for: req)
    }

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

	static func batching(_ name: String, fields: [Element], idList: [String], perNodeBlock: BatchGroup.NodeBlock? = nil) -> [Query] {
		var list = idList
		var segments = [[String]]()
		while list.hasItems {
			let p = min(config.pageSize, list.count)
			segments.append(Array(list[0..<p]))
			list = Array(list[p...])
		}
		var isNext = false
		return segments.map {
			let q = Query(name: name, rootElement: BatchGroup(templateGroup: Group(name: "items", fields: fields), idList: $0, perNodeBlock: perNodeBlock), subQuery: isNext)
			if !isNext {
				isNext = true
			}
			return q
		}
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

    private static let RETRY_COUNT = 3

	func run(shouldRetry: Int = Query.RETRY_COUNT) async -> Bool {

		func errorCompletion(_ message: String) async -> Bool {
			if shouldRetry > 1 {
				log(level: .verbose, "[*\(name)*] \(message)")
				log(level: .verbose, "[*\(name)*] Retrying")
				return await run(shouldRetry: shouldRetry-1)
			} else {
				log("[*\(name)*] \(message)")
				return false
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

		if shouldRetry == Query.RETRY_COUNT && !subQuery {
			log("[*\(name)*] Fetching")
		}
		let Q = queryText
		log(level: .debug, "[*\(name)*] \(Q)")

		var req = URLRequest(url: config.server)
        req.httpMethod = "POST"
        req.httpBody = try! JSONEncoder().encode(["query": Q])

        let info: Data
        do {
            (info, _) = try await Query.getData(for: req)
        } catch {
            return await errorCompletion("Network error: \(error.localizedDescription)")
        }
        
        guard let json = (try? JSONSerialization.jsonObject(with: info, options: [])) as? [AnyHashable : Any] else {
            return await errorCompletion("No JSON in response")
        }
        
        guard let data = extractNodeData(from: json) else {
            if let errors = json["errors"] as? [[AnyHashable:Any]] {
                let msg = errors.first?["message"] as? String ?? "Unspecified server error: \(json)"
                return await errorCompletion("Failed with error: '\(msg)'")
            } else {
                let msg = json["message"] as? String ?? "Unspecified server error: \(json)"
                return await errorCompletion("Failed with error: '\(msg)'")
            }
        }
        
        if let rateLimit = extractRateLimit(from: json), let cost = rateLimit["cost"] as? Int, let remaining = rateLimit["remaining"] as? Int, let nodeCount = rateLimit["nodeCount"] as? Int {
            config.totalQueryCosts += cost
            config.totalApiRemaining = min(config.totalApiRemaining, remaining)
            log(level: .verbose, "[*\(self.name)*] Processed page (Cost: [!\(cost)!], Remaining: [!\(remaining)!] - Node Count: [!\(nodeCount)!])")
        } else {
            log(level: .verbose, "[*\(self.name)*] Processed page")
        }
        
        let root = self.rootElement
        guard let topData = data[root.name] else {
            return await errorCompletion("No data in JSON")
        }
        
        let extraQueries = await root.ingest(query: self, pageData: topData, parent: self.parent, level: 0)
        if extraQueries.isEmpty {
            return true
        }
        
        log(level: .debug, "[*\(name)*] Needs more page data")
        return await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for e in extraQueries {
                group.addTask {
                    return await e.run()
                }
            }
            return !(await group.contains(false))
        }
	}
}
