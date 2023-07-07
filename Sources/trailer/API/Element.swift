import Foundation

protocol Element {
    var name: String { get }
    var queryText: String { get }
    var fragments: LinkedList<Fragment> { get }
}
