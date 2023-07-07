import Foundation

let emptyList = LinkedList<Fragment>()

struct Field: Element {
    let name: String
    var queryText: String { name }
    var fragments: LinkedList<Fragment> { emptyList }

    static let id = Field(name: "id")
}
