import Foundation

protocol Identifiable: Codable {
    var id: String { get set }
    var elementType: String { get set }
    var syncState: SyncState { get set }
}

extension Identifiable {
    static var typeName: String {
        String(describing: type(of: self)).components(separatedBy: ".").first!
    }

    var typeName: String {
        String(describing: type(of: self)).components(separatedBy: ".").first!
    }
}
