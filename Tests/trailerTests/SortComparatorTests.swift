import Foundation
import Testing
@testable import trailer

/// A stand-in for PullRequest/Issue that only carries the fields the comparators read.
@MainActor
private struct SortFixture: Sortable {
    var title = ""
    var createdAt = Date.distantPast
    var updatedAt = Date.distantPast
    var headRefName = ""
    var number = 0
    var repo: Repo?
    var author: User?
    var type = 0
}

@Suite("List sort criteria")
@MainActor
struct SortComparatorTests {
    private func order(_ criteria: [ListSortDefinition.Criterion], _ lhs: SortFixture, _ rhs: SortFixture) -> ComparisonResult {
        let definition = ListSortDefinition(criteria: criteria)
        if definition.isAscending(lhs, rhs) { return .orderedAscending }
        if definition.isAscending(rhs, lhs) { return .orderedDescending }
        return .orderedSame
    }

    @Test("Numbers sort numerically")
    func byNumber() {
        #expect(order([.number], SortFixture(number: 2), SortFixture(number: 10)) == .orderedAscending)
        #expect(order([.number], SortFixture(number: 10), SortFixture(number: 2)) == .orderedDescending)
        #expect(order([.number], SortFixture(number: 7), SortFixture(number: 7)) == .orderedSame)
    }

    @Test("Titles sort case insensitively")
    func byTitle() {
        #expect(order([.title], SortFixture(title: "apple"), SortFixture(title: "Banana")) == .orderedAscending)
        #expect(order([.title], SortFixture(title: "Zebra"), SortFixture(title: "apple")) == .orderedDescending)
        #expect(order([.title], SortFixture(title: "Same"), SortFixture(title: "same")) == .orderedSame)
    }

    @Test("Branch names sort case insensitively")
    func byBranch() {
        #expect(order([.branch], SortFixture(headRefName: "alpha"), SortFixture(headRefName: "Beta")) == .orderedAscending)
    }

    @Test("Dates sort oldest first")
    func byDate() {
        let old = Date(timeIntervalSince1970: 1000)
        let new = Date(timeIntervalSince1970: 2000)
        #expect(order([.created], SortFixture(createdAt: old), SortFixture(createdAt: new)) == .orderedAscending)
        #expect(order([.updated], SortFixture(updatedAt: new), SortFixture(updatedAt: old)) == .orderedDescending)
    }

    @Test("Type orders PRs (0) before Issues (1)")
    func byType() {
        #expect(order([.type], SortFixture(type: 0), SortFixture(type: 1)) == .orderedAscending)
    }

    @Test("A missing author or repo sorts as an empty string rather than crashing")
    func missingOptionalFields() {
        #expect(order([.author], SortFixture(), SortFixture()) == .orderedSame)
        #expect(order([.repo], SortFixture(), SortFixture()) == .orderedSame)
    }

    @Test("Later criteria break ties left by earlier ones")
    func tieBreaking() {
        let a = SortFixture(title: "zzz", number: 1)
        let b = SortFixture(title: "aaa", number: 1)
        // Equal numbers, so the title decides.
        #expect(order([.number, .title], a, b) == .orderedDescending)
        // Number decides first, so the title is never consulted.
        let c = SortFixture(title: "zzz", number: 1)
        let d = SortFixture(title: "aaa", number: 2)
        #expect(order([.number, .title], c, d) == .orderedAscending)
    }

    @Test("Fully equal items compare as same under the default criteria")
    func defaultCriteria() {
        #expect(order(ListSortDefinition.defaultCriteria, SortFixture(), SortFixture()) == .orderedSame)
    }

    @Test("-sort is parsed, and falls back to the default when absent or unrecognised")
    func criteriaParsing() {
        func comparatorCount(_ arguments: [String]) -> Int {
            ListSortDefinition(arguments: ArgumentList(arguments)).comparators.count
        }

        let defaultCount = ListSortDefinition.defaultCriteria.count
        #expect(comparatorCount(["trailer"]) == defaultCount)
        #expect(comparatorCount(["trailer", "-sort", "number,title"]) == 2)
        // Nothing recognised, so the default ordering is used.
        #expect(comparatorCount(["trailer", "-sort", "garbage"]) == defaultCount)
        // Unrecognised entries are dropped, the rest are honoured.
        #expect(comparatorCount(["trailer", "-sort", "repo,bogus,author"]) == 2)
    }
}
