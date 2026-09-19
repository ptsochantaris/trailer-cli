import Foundation

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

    static func == (lhs: Relationship, rhs: Relationship) -> Bool {
        lhs.parentId == rhs.parentId
    }
}
