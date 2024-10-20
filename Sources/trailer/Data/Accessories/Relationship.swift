import Foundation

@MainActor
struct Relationship: Codable, Equatable {
    let parentId: String
    var syncState = SyncState.none

    private enum CodingKeys: CodingKey {
        case parentId
    }

    init(to parent: Parent) {
        parentId = parent.item.id
        syncState = .new
    }

    nonisolated static func == (lhs: Relationship, rhs: Relationship) -> Bool {
        lhs.parentId == rhs.parentId
    }
}
