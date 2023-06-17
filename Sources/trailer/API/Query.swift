//
//  Query.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Query {
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

    static func batching(_ name: String, fields: [Element], idList: [String], perNodeBlock: BatchGroup.NodeBlock? = nil) -> LinkedList<Query> {
        var list = idList
        var isNext = false
        let res = LinkedList<Query>()
        while list.hasItems {
            let p = min(config.pageSize, list.count)
            let segment = Array(list[0 ..< p])
            let q = Query(name: name, rootElement: BatchGroup(templateGroup: Group(name: "items", fields: fields), idList: segment, perNodeBlock: perNodeBlock), subQuery: isNext)
            res.append(q)
            isNext = true
            list.removeFirst(p)
        }
        return res
    }

    var queryText: String {
        let fragments = LinkedList<Fragment>()
        var processedNames = Set<String>()
        for f in rootElement.fragments {
            if processedNames.insert(f.name).inserted {
                fragments.append(f)
            }
        }

        let text = fragments.map(\.declaration).joined(separator: " ")
        var rootQuery = rootElement.queryText
        if let parentItem = parent?.item {
            rootQuery = "node(id: \"\(parentItem.id)\") { ... on \(parentItem.elementType) { " + rootQuery + " } }"
        }
        return text + " { " + rootQuery + " rateLimit { limit cost remaining resetAt nodeCount } }"
    }

    private static let RETRY_COUNT = 3

    func run(shouldRetry: Int = Query.RETRY_COUNT) async throws {
        func retryOrFail(_ message: String) async throws {
            if shouldRetry > 1 {
                log(level: .verbose, "[*\(name)*] \(message)")
                log(level: .verbose, "[*\(name)*] Retrying")
                try await run(shouldRetry: shouldRetry - 1)
            } else {
                log("[*\(name)*] \(message)")
                throw NSError(domain: "build.bru.trailer-cli.query", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }

        func extractNodeData(from json: JSON) -> JSON? {
            if let data = json["data"] as? JSON {
                if parent == nil {
                    return data
                } else {
                    return data["node"] as? JSON
                }
            }
            return nil
        }

        func extractRateLimit(from json: JSON) -> JSON? {
            if let data = json["data"] as? JSON {
                return data["rateLimit"] as? JSON
            }
            return nil
        }

        if shouldRetry == Query.RETRY_COUNT, !subQuery {
            log("[*\(name)*] Fetching")
        }
        let Q = queryText
        log(level: .debug, "[*\(name)*] \(Q)")

        let info: Data
        do {
            let body = try JSONEncoder().encode(["query": Q])
            let req = Network.Request(url: config.server.absoluteString, method: .post, body: body)
            info = try await Network.getData(for: req)
        } catch {
            try await retryOrFail("Query error: \(error.localizedDescription)")
            return
        }

        guard let json = (try? FoundationJson.jsonObject(with: info)) as? JSON else {
            try await retryOrFail("No JSON in API response: \(String(data: info, encoding: .utf8) ?? "")")
            return
        }

        guard let data = extractNodeData(from: json) else {
            let msg: String
            if let errors = json["errors"] as? [JSON] {
                msg = errors.first?["message"] as? String ?? "Unspecified server error: \(json)"
            } else {
                msg = json["message"] as? String ?? "Unspecified server error: \(json)"
            }
            try await retryOrFail("Failed with error: '\(msg)'")
            return
        }

        if let rateLimit = extractRateLimit(from: json), let cost = rateLimit["cost"] as? Int, let remaining = rateLimit["remaining"] as? Int, let nodeCount = rateLimit["nodeCount"] as? Int {
            config.totalQueryCosts += cost
            config.totalApiRemaining = min(config.totalApiRemaining, remaining)
            log(level: .verbose, "[*\(name)*] Processed page (Cost: [!\(cost)!], Remaining: [!\(remaining)!] - Node Count: [!\(nodeCount)!])")
        } else {
            log(level: .verbose, "[*\(name)*] Processed page")
        }

        let root = rootElement
        guard let topData = data[root.name] else {
            try await retryOrFail("No data in JSON")
            return
        }

        let extraQueries = root.ingest(query: self, pageData: topData, parent: parent, level: 0)
        if extraQueries.count == 0 {
            return
        }

        log(level: .debug, "[*\(name)*] Needs more page data")
        try await Query.attempt(extraQueries)
    }

    static func attempt(_ queries: LinkedList<Query>) async throws {
        for q in queries {
            try await q.run()
        }
    }
}
