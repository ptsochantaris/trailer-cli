import Foundation

protocol Identifiable: Codable {
    var id: String { get set }
    @MainActor
    var elementType: String { get set }
    @MainActor
    var syncState: SyncState { get set }
    @MainActor
    static var typeName: String { get }
}

extension Identifiable {
    @MainActor
    var typeName: String {
        Self.typeName
    }
}
