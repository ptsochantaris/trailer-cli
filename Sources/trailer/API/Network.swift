//
//  Network.swift
//  trailer
//
//  Created by Paul Tsochantaris on 08/01/2023.
//

import Foundation

enum Network {
    struct Request {
        enum Method: String {
            case post, get
        }
        let url: String
        let method: Method
        let body: Data?
    }
    
    struct Response {
        let data: Data
    }
}

#if canImport(AsyncHTTPClient)
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import NIOFoundationCompat

extension Network {
    private static let httpClient = HTTPClient(eventLoopGroupProvider: .createNew,
                                               configuration: HTTPClient.Configuration(certificateVerification: .fullVerification,
                                                                                       redirectConfiguration: .disallow,
                                                                                       decompression: .enabled(limit: .none)))

    static func getData(for request: Request) async throws -> Data {
        var req = HTTPClientRequest(url: request.url)
        req.headers = HTTPHeaders(config.httpHeaders)
        switch request.method {
        case .get:
            break
        case .post:
            req.method = .POST
            if let body = request.body {
                req.body = HTTPClientRequest.Body.bytes(ByteBuffer(data: body))
            }
        }
        let res = try await httpClient.execute(req, timeout: .seconds(60))
        let buffer = try await res.body.collect(upTo: Int.max)
        return Data(buffer: buffer)
    }
}

#else

extension Network {
    private static let urlSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpMaximumConnectionsPerHost = 1
        c.httpShouldUsePipelining = true
        c.httpAdditionalHeaders = Dictionary<String, String>(uniqueKeysWithValues: config.httpHeaders)
        return URLSession(configuration: c, delegate: nil, delegateQueue: nil)
    }()
        
    static func getData(for request: Request) async throws -> Data {
        var req = URLRequest(url: URL(string: request.url)!)
        req.httpMethod = request.method.rawValue
        req.httpBody = request.body
        return try await urlSession.data(for: req).0
    }
}
#endif
