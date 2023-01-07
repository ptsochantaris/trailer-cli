//
//  Query.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import AsyncHTTPClient
import Foundation
import NIOCore

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

enum Network {
    private static let httpClient = HTTPClient(eventLoopGroupProvider: .createNew,
                                               configuration: HTTPClient.Configuration(certificateVerification: .fullVerification,
                                                                                       redirectConfiguration: .disallow,
                                                                                       decompression: .enabled(limit: .none)))

    static func getData(for request: HTTPClientRequest) async throws -> (Data, HTTPClientResponse) {
        var request = request
        request.headers = config.httpHeaders
        let res = try await httpClient.execute(request, timeout: .seconds(60))
        let buffer = try await res.body.collect(upTo: Int.max)
        return (Data(buffer: buffer), res)
    }
}

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
        var segments = [[String]]()
        while list.hasItems {
            let p = min(config.pageSize, list.count)
            segments.append(Array(list[0 ..< p]))
            list = Array(list[p...])
        }
        var isNext = false
        let res = LinkedList<Query>()
        for segment in segments {
            let q = Query(name: name, rootElement: BatchGroup(templateGroup: Group(name: "items", fields: fields), idList: segment, perNodeBlock: perNodeBlock), subQuery: isNext)
            isNext = true
            res.append(q)
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

        let text = fragments.map { $0.declaration }.joined(separator: " ")
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

        func extractNodeData(from json: [AnyHashable: Any]) -> [AnyHashable: Any]? {
            if let data = json["data"] as? [AnyHashable: Any] {
                if parent == nil {
                    return data
                } else {
                    return data["node"] as? [AnyHashable: Any]
                }
            }
            return nil
        }

        func extractRateLimit(from json: [AnyHashable: Any]) -> [AnyHashable: Any]? {
            if let data = json["data"] as? [AnyHashable: Any] {
                return data["rateLimit"] as? [AnyHashable: Any]
            }
            return nil
        }

        if shouldRetry == Query.RETRY_COUNT, !subQuery {
            log("[*\(name)*] Fetching")
        }
        let Q = queryText
        log(level: .debug, "[*\(name)*] \(Q)")

        var req = HTTPClientRequest(url: config.server.absoluteString)
        req.method = .POST
        req.body = HTTPClientRequest.Body.bytes(ByteBuffer(data: try! JSONEncoder().encode(["query": Q])))

        let info: Data
        do {
            (info, _) = try await Network.getData(for: req)
        } catch {
            try await retryOrFail("Network error: \(error.localizedDescription)")
            return
        }

        guard let json = (try? JSONSerialization.jsonObject(with: info, options: [])) as? [AnyHashable: Any] else {
            try await retryOrFail("No JSON in response")
            return
        }

        guard let data = extractNodeData(from: json) else {
            let msg: String
            if let errors = json["errors"] as? [[AnyHashable: Any]] {
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
        try await withThrowingTaskGroup(of: Void.self) { group in
            for q in queries {
                group.addTask {
                    try await q.run()
                }
            }
            try await group.waitForAll()
        }
    }
}
