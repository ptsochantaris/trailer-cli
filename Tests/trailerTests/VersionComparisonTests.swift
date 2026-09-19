import Testing
@testable import trailer

/// `Config.isNewer` compares a tag from the releases API against the built-in version, which is
/// currently 1.7.0. Before this was fixed it ignored its input entirely and always returned false,
/// so the "new version available" banner never appeared.
@Suite("Release version comparison")
struct VersionComparisonTests {
    @Test("The suite's expectations match the version actually built")
    func builtVersion() {
        #expect(Config().versionString == "1.7.0")
    }

    @Test("A later version is newer", arguments: ["1.7.1", "1.8.0", "2.0.0", "1.10.0"])
    func laterVersions(_ version: String) {
        #expect(Config.isNewer(version))
    }

    @Test("The current and earlier versions are not newer", arguments: ["1.7.0", "1.6.9", "1.6.0", "1.0.0", "0.9.9"])
    func sameOrEarlierVersions(_ version: String) {
        #expect(!Config.isNewer(version))
    }

    @Test("Unparseable tags are not treated as newer", arguments: ["", "1.7", "1.7.0.1", "v1.8.0", "garbage", "a.b.c"])
    func malformedVersions(_ version: String) {
        #expect(!Config.isNewer(version))
    }

    @Test("Comparison is numeric, not lexicographic")
    func numericNotLexicographic() {
        // "1.10.0" < "1.7.0" as strings, but 10 > 7 as numbers.
        #expect(Config.isNewer("1.10.0"))
        #expect(!Config.isNewer("1.07.0"))
    }
}
