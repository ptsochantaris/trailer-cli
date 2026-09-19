import Testing
@testable import trailer

@Suite("Command line argument parsing")
struct ArgumentParsingTests {
    @Test("A flag's value is the entry that follows it")
    func valueFollowsFlag() {
        let args = ArgumentList(["trailer", "-server", "https://example.com/graphql"])
        #expect(args.value(for: "-server") == "https://example.com/graphql")
    }

    @Test("An absent flag has no value, a valueless flag has an empty one")
    func absentVersusValueless() {
        let args = ArgumentList(["trailer", "-mono", "-token"])
        #expect(args.value(for: "-server") == nil)
        // Present but nothing follows it.
        #expect(args.value(for: "-token") == "")
        // Present but followed by another flag rather than a value.
        #expect(args.value(for: "-mono") == "")
    }

    @Test("Lookup is case insensitive, and keepCase preserves the value's original casing")
    func caseHandling() {
        let args = ArgumentList(["trailer", "-TOKEN", "AbCdEf123"])
        #expect(args.value(for: "-token") == "abcdef123")
        #expect(args.value(for: "-token", keepCase: true) == "AbCdEf123")
    }

    @Test("contains reports flag presence")
    func contains() {
        let args = ArgumentList(["trailer", "list", "-Mono"])
        #expect(args.contains("-mono"))
        #expect(!args.contains("-dryrun"))
    }

    @Test("first(matching:) returns the normalised argument, or nil")
    func firstMatching() {
        let args = ArgumentList(["trailer", "Stats"])
        #expect(args.first(matching: "stats") == "stats")
        #expect(args.first(matching: "reset") == nil)
    }

    @Test("A sequence runs from its start word up to the next flag")
    func sequenceStopsAtFlag() {
        let args = ArgumentList(["trailer", "show", "pr", "42", "-body", "-comments"])
        #expect(args.sequence(starting: "show") == ["show", "pr", "42"])
    }

    @Test("A sequence runs to the end when no flag follows")
    func sequenceRunsToEnd() {
        let args = ArgumentList(["trailer", "update", "all"])
        #expect(args.sequence(starting: "update") == ["update", "all"])
    }

    @Test("A start word with nothing after it yields just itself")
    func sequenceOfOne() {
        let args = ArgumentList(["trailer", "list"])
        #expect(args.sequence(starting: "list") == ["list"])
    }

    @Test("An absent start word yields nil, which is how 'no action given' is detected")
    func sequenceAbsent() {
        let args = ArgumentList(["trailer", "-version"])
        #expect(args.sequence(starting: "list") == nil)
    }
}
