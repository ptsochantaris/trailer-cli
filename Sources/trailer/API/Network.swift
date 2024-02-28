import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Semalot

enum Network {
    struct Request {
        enum Method: String {
            case post, get
        }

        let url: String
        let method: Method
        let body: Data?
    }

    private static let urlSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpMaximumConnectionsPerHost = 1
        c.httpShouldUsePipelining = true
        c.httpAdditionalHeaders = [String: String](uniqueKeysWithValues: config.httpHeaders)
        return URLSession(configuration: c, delegate: nil, delegateQueue: nil)
    }()

    static let networkGate = Semalot(tickets: 2)

    static func getData(for request: Request) async throws -> Data {
        var req = URLRequest(url: URL(string: request.url)!)
        req.httpMethod = request.method.rawValue
        req.httpBody = request.body
        await networkGate.takeTicket()
        defer {
            networkGate.returnTicket()
        }
        #if canImport(FoundationNetworking)
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                let task = urlSession.dataTask(with: req) { data, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data ?? Data())
                    }
                }
                task.resume()
            }
        #else
            return try await urlSession.data(for: req).0
        #endif
    }
}
