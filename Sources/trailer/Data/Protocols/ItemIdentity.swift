import Foundation

/// The identity and sync bookkeeping shared by every stored type. Kept separate from `Item` so that
/// `Parent` can hold one as an existential; `Item` has `Self` requirements and cannot be used that way.
@MainActor
protocol ItemIdentity: Codable {
    var id: String { get set }
    var elementType: String { get set }
    var syncState: SyncState { get set }
    static var typeName: String { get }
}

extension ItemIdentity {
    var typeName: String {
        Self.typeName
    }
}
