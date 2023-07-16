import Foundation

protocol Identifiable: Codable {
    var id: String { get set }
    var elementType: String { get set }
    var syncState: SyncState { get set }
    static var typeName: String { get }
}

extension Identifiable {
    var typeName: String {
        Self.typeName
    }
}
