import Testing
@testable import trailer

/// Serialized because `postProcess` reads the shared `config.monochrome` flag.
@Suite("Terminal markup", .serialized)
@MainActor
struct TTYTests {
    private func withColour<T>(_ enabled: Bool, _ body: () -> T) -> T {
        let previous = config.monochrome
        defer { config.monochrome = previous }
        config.monochrome = !enabled
        return body()
    }

    @Test("Every marker maps to its ANSI escape")
    func allMarkers() {
        withColour(true) {
            #expect(TTY.postProcess("[R*") == "\u{1b}[31m")
            #expect(TTY.postProcess("[G*") == "\u{1b}[32m")
            #expect(TTY.postProcess("[B*") == "\u{1b}[34m")
            #expect(TTY.postProcess("[C*") == "\u{1b}[36m")
            #expect(TTY.postProcess("[*") == "\u{1b}[33m")
            #expect(TTY.postProcess("[!") == "\u{1b}[1m")
            #expect(TTY.postProcess("[$") == "\u{1b}[2m")
            #expect(TTY.postProcess("[&") == "\u{1b}[5m")
            #expect(TTY.postProcess("*]") == "\u{1b}[39m")
            #expect(TTY.postProcess("!]") == "\u{1b}[22m")
            #expect(TTY.postProcess("&]") == "\u{1b}[25m")
        }
    }

    @Test("Three-character colour markers win over the two-character prefix they share")
    func longestMatchWins() {
        withColour(true) {
            // "[R*" must not be read as "[" followed by "R*".
            #expect(TTY.postProcess("[R*red*]") == "\u{1b}[31mred\u{1b}[39m")
            #expect(TTY.postProcess("[*plain*]") == "\u{1b}[33mplain\u{1b}[39m")
        }
    }

    @Test("A typical formatted line round-trips")
    func formattedLine() {
        withColour(true) {
            #expect(TTY.postProcess("[!Hello!]") == "\u{1b}[1mHello\u{1b}[22m")
        }
    }

    @Test("Monochrome mode strips markers rather than colouring them")
    func monochromeStrips() {
        withColour(false) {
            #expect(TTY.postProcess("[!Hello!]") == "Hello")
            #expect(TTY.postProcess("[R*red*]") == "red")
            #expect(TTY.postProcess("[$Repo!] name") == "Repo name")
        }
    }

    /// Regression: the old state machine dropped the character after any incomplete marker, so a
    /// title like "Fix [bug] in parser" rendered as "Fix [ug] in parser".
    @Test("Text that merely looks like markup is passed through intact", arguments: [
        "Fix [bug] in parser",
        "a[b",
        "[Red",
        "100% done",
        "a*b",
        "!important",
        "Tom & Jerry",
        "array[index] = *pointer"
    ])
    func nonMarkupSurvives(_ text: String) {
        withColour(true) {
            #expect(TTY.postProcess(text) == text)
        }
        withColour(false) {
            #expect(TTY.postProcess(text) == text)
        }
    }

    @Test("Truncated markers at end of string are preserved", arguments: ["[", "[R", "*", "&", "!"])
    func truncatedMarkers(_ text: String) {
        withColour(true) {
            #expect(TTY.postProcess(text) == text)
        }
    }

    @Test("Plain text is unchanged")
    func plainText() {
        withColour(true) {
            #expect(TTY.postProcess("hello") == "hello")
            #expect(TTY.postProcess("") == "")
        }
    }

    @Test("rightAlign pads to 15 columns and never truncates")
    func rightAlign() {
        #expect(TTY.rightAlign("#42") == "            #42")
        #expect(TTY.rightAlign("#42").count == 15)
        let long = "#1234567890123456789"
        #expect(TTY.rightAlign(long) == long)
    }
}
