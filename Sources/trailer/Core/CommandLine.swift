import Foundation

/// The command-line parsing logic, held separately from the process's own arguments so it can be
/// exercised in tests with a synthetic argument list.
nonisolated struct ArgumentList: Sendable {
    private let original: [String]
    private let lowercased: [String]

    init(_ arguments: [String]) {
        original = arguments
        lowercased = arguments.map { $0.lowercased() }
    }

    /// The value following `argument`. Returns `nil` if the argument is absent, and an empty string
    /// if it is present but has no value (either nothing follows it, or the next entry is a flag).
    func value(for argument: String, keepCase: Bool = false) -> String? {
        guard let index = lowercased.firstIndex(of: argument) else { return nil }

        let valueIndex = index + 1
        guard valueIndex < lowercased.count else { return "" }

        let nextArg = keepCase ? original[valueIndex] : lowercased[valueIndex]
        return nextArg.hasPrefix("-") ? "" : nextArg
    }

    func contains(_ argument: String) -> Bool {
        lowercased.contains(argument)
    }

    func first(matching argument: String) -> String? {
        lowercased.first { $0 == argument }
    }

    /// `argument` plus every following entry up to the next flag, e.g. `["show", "pr", "42"]`.
    func sequence(starting: String) -> [String]? {
        guard let index = lowercased.firstIndex(of: starting) else { return nil }

        let rest = lowercased[(index + 1)...].prefix { !$0.hasPrefix("-") }
        return [starting] + rest
    }
}

extension CommandLine {
    private static let parsed = ArgumentList(CommandLine.arguments)

    static func value(for argument: String, keepCase: Bool = false) -> String? {
        parsed.value(for: argument, keepCase: keepCase)
    }

    static func argument(exists argument: String) -> Bool {
        parsed.contains(argument)
    }

    static func argument(matching argument: String) -> String? {
        parsed.first(matching: argument)
    }

    static func sequence(starting: String) -> [String]? {
        parsed.sequence(starting: starting)
    }
}

let listFieldsDefinition = ListFieldsDefinition()

struct ListFieldsDefinition {
    let type, number, title, repo, branch, author, created, updated, url, labels: Bool
    init() {
        let components = CommandLine.value(for: "-fields")?.split(separator: ",")
        type = components?.contains("type") ?? true
        number = components?.contains("number") ?? true
        author = components?.contains("author") ?? true
        title = components?.contains("title") ?? true
        repo = components?.contains("repo") ?? true
        branch = components?.contains("branch") ?? false
        created = components?.contains("created") ?? false
        updated = components?.contains("updated") ?? false
        labels = components?.contains("labels") ?? false
        url = components?.contains("url") ?? false
    }
}

struct ListSortDefinition {
    enum Criterion: String, CaseIterable {
        case number, title, repo, branch, author, created, updated, type
    }

    static let defaultCriteria: [Criterion] = [.number, .title, .created]

    let comparators: [@MainActor (any Sortable, any Sortable) -> ComparisonResult]

    init(criteria: [Criterion]) {
        comparators = criteria.map { criterion in
            switch criterion {
            case .number: { Self.compare($0.number, $1.number) }
            case .created: { Self.compare($0.createdAt, $1.createdAt) }
            case .updated: { Self.compare($0.updatedAt, $1.updatedAt) }
            case .type: { Self.compare($0.type, $1.type) }
            case .title: { $0.title.localizedCaseInsensitiveCompare($1.title) }
            case .branch: { $0.headRefName.localizedCaseInsensitiveCompare($1.headRefName) }
            case .author: { Self.compareText($0.author?.login, $1.author?.login) }
            case .repo: { Self.compareText($0.repo?.nameWithOwner, $1.repo?.nameWithOwner) }
            }
        }
    }

    /// Parses `-sort`, falling back to the default ordering if it is absent or lists nothing valid.
    init(arguments: ArgumentList) {
        let requested = arguments.value(for: "-sort")?
            .split(separator: ",")
            .compactMap { Criterion(rawValue: String($0)) }
        self.init(criteria: (requested?.isEmpty == false) ? requested! : Self.defaultCriteria)
    }

    /// Applies each comparator in turn, the first non-equal result winning.
    @MainActor
    func isAscending(_ lhs: any Sortable, _ rhs: any Sortable) -> Bool {
        for comparator in comparators {
            switch comparator(lhs, rhs) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: continue
            }
        }
        return false
    }

    private static func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { .orderedAscending } else if rhs < lhs { .orderedDescending } else { .orderedSame }
    }

    private static func compareText(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        (lhs ?? "").localizedCaseInsensitiveCompare(rhs ?? "")
    }
}

private let listSortDefinition = ListSortDefinition(arguments: ArgumentList(CommandLine.arguments))

extension Array where Element: Sortable {
    var sortedByCriteria: [Element] {
        sorted { listSortDefinition.isAscending($0, $1) }
    }
}
