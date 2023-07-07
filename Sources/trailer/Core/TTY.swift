import Foundation

struct TTY {
    static func rightAlign(_ message: String) -> String {
        let c = max(0, 15 - message.count)
        let spaces = String(repeating: " ", count: c)
        return spaces + message
    }

    static func postProcess(_ message: String) -> String {
        if config.monochrome {
            return message
                .replacingOccurrences(of: "[R*", with: "")
                .replacingOccurrences(of: "[G*", with: "")
                .replacingOccurrences(of: "[*", with: "")
                .replacingOccurrences(of: "[B*", with: "")
                .replacingOccurrences(of: "[C*", with: "")
                .replacingOccurrences(of: "*]", with: "")
                .replacingOccurrences(of: "[!", with: "")
                .replacingOccurrences(of: "[$", with: "")
                .replacingOccurrences(of: "!]", with: "")
                .replacingOccurrences(of: "[&", with: "")
                .replacingOccurrences(of: "&]", with: "")

        } else {
            return message
                .replacingOccurrences(of: "[R*", with: "\u{1b}[31m")
                .replacingOccurrences(of: "[G*", with: "\u{1b}[32m")
                .replacingOccurrences(of: "[*", with: "\u{1b}[33m")
                .replacingOccurrences(of: "[B*", with: "\u{1b}[34m")
                .replacingOccurrences(of: "[C*", with: "\u{1b}[36m")
                .replacingOccurrences(of: "*]", with: "\u{1b}[39m")
                .replacingOccurrences(of: "[!", with: "\u{1b}[1m")
                .replacingOccurrences(of: "[$", with: "\u{1b}[2m")
                .replacingOccurrences(of: "!]", with: "\u{1b}[22m")
                .replacingOccurrences(of: "[&", with: "\u{1b}[5m")
                .replacingOccurrences(of: "&]", with: "\u{1b}[25m")
        }
    }
}
