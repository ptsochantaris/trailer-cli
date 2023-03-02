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
}

#if canImport(AsyncHTTPClient)
    import AsyncHTTPClient
    import NIOCore
    import NIOFoundationCompat
    import NIOHTTP1

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

    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif

    extension Network {
        private static let urlSession: URLSession = {
            let c = URLSessionConfiguration.default
            c.httpMaximumConnectionsPerHost = 1
            c.httpShouldUsePipelining = true
            c.httpAdditionalHeaders = [String: String](uniqueKeysWithValues: config.httpHeaders)
            return URLSession(configuration: c, delegate: nil, delegateQueue: nil)
        }()

        static func getData(for request: Request) async throws -> Data {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                var req = URLRequest(url: URL(string: request.url)!)
                req.httpMethod = request.method.rawValue
                req.httpBody = request.body
                let task = urlSession.dataTask(with: req) { data, _, error in
                    if let data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: error ?? NSError(domain: "build.bru.trailer-cli.network", code: 92, userInfo: [NSLocalizedDescriptionKey: "No data or error from server"]))
                    }
                }
                task.resume()
            }
        }
    }
#endif
