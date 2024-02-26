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

    private enum PostProcessState {
        case one, two, three
    }

    static func postProcess(_ message: String) -> String {
        let colour = !config.monochrome

        var output = ""
        output.reserveCapacity(message.count)

        var pending = ""
        pending.reserveCapacity(3)

        var state = PostProcessState.one
        for c in message {
            switch state {
            case .one:
                switch c {
                case "!", "[", "*", "&":
                    pending.append(c)
                    state = .two
                default:
                    output.append(c)
                }
            case .two:
                switch c {
                case "B", "C", "G", "R":
                    pending.append(c)
                    state = .three
                case "!", "]", "*", "&", "$":
                    pending.append(c)
                    if colour, let replacement = colourMap[pending] {
                        output.append(replacement)
                    }
                    pending = ""
                    state = .one
                default:
                    output.append(pending)
                    pending = ""
                    state = .one
                }
            case .three:
                if c == "*" {
                    pending.append(c)
                    if colour, let replacement = colourMap[pending] {
                        output.append(replacement)
                    }
                } else {
                    output.append(pending)
                }
                pending = ""
                state = .one
            }
        }
        return output
    }
}
