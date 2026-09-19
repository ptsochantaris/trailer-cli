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
        // A single connection is plenty: the GitHub API speaks HTTP/2, so concurrent queries are
        // multiplexed as streams over it. (HTTP/1 pipelining used to be requested here, but it is
        // deprecated and ignored once HTTP/2 is negotiated.)
        c.httpMaximumConnectionsPerHost = 1
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
        return try await urlSession.data(for: req).0
    }
}
