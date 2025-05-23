import Foundation

@MainActor
func log(level: Config.LogLevel = .info, indent: Int = 0, _ message: @autoclosure () -> String = "", unformatted: Bool = false) {
    if config.globalLogLevel > level { return }
    if indent > 0 {
        let spaces = String(repeating: " ", count: indent)
        print(spaces, terminator: "")
    }
    let m = message()
    if m.isEmpty {
        print()
    } else {
        if unformatted {
            print(m)
        } else {
            print(TTY.postProcess(m))
        }
    }
}

@MainActor
func open(url: URL) {
    log("Opening url: [*\(url)*]")
    let p = Process()
    p.arguments = [url.absoluteString]
    #if os(macOS)
        p.launchPath = "/usr/bin/open"
        p.launch()
    #else
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        try? p.run()
    #endif
}

extension Collection {
    var hasItems: Bool {
        !isEmpty
    }
}
