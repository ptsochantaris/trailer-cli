import Foundation

enum TTY {
    static func rightAlign(_ message: String) -> String {
        let c = max(0, 15 - message.count)
        let spaces = String(repeating: " ", count: c)
        return spaces + message
    }

    private static let colourMap = [
        "[R*": "\u{1b}[31m",
        "[G*": "\u{1b}[32m",
        "[B*": "\u{1b}[34m",
        "[C*": "\u{1b}[36m",
        "[*": "\u{1b}[33m",
        "[!": "\u{1b}[1m",
        "[$": "\u{1b}[2m",
        "[&": "\u{1b}[5m",
        "*]": "\u{1b}[39m",
        "!]": "\u{1b}[22m",
        "&]": "\u{1b}[25m"
    ]

    /// Marker lengths, longest first, so that the three-character colour codes win over the
    /// two-character ones sharing their prefix (`[R*` before `[*`).
    private static let markerLengths = Set(colourMap.keys.map(\.count)).sorted(by: >)

    /// Replaces the `[!`…`!]` style markup with ANSI escapes, or strips it in monochrome mode.
    /// Anything that is not a complete marker is passed through untouched, so item titles
    /// containing brackets or asterisks survive intact.
    static func postProcess(_ message: String) -> String {
        let colour = !config.monochrome

        var output = ""
        output.reserveCapacity(message.count)

        var index = message.startIndex
        while index < message.endIndex {
            if let (length, replacement) = marker(in: message, at: index) {
                if colour {
                    output.append(replacement)
                }
                index = message.index(index, offsetBy: length)
            } else {
                output.append(message[index])
                index = message.index(after: index)
            }
        }
        return output
    }

    private static func marker(in message: String, at index: String.Index) -> (length: Int, replacement: String)? {
        for length in markerLengths {
            guard let end = message.index(index, offsetBy: length, limitedBy: message.endIndex) else { continue }
            if let replacement = colourMap[String(message[index ..< end])] {
                return (length, replacement)
            }
        }
        return nil
    }
}
