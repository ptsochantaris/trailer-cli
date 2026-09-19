import Foundation

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

func open(url: URL) {
    log("Opening url: [*\(url)*]")
    let p = Process()
    p.executableURL = URL(filePath: "/usr/bin/open")
    p.arguments = [url.absoluteString]
    do {
        try p.run()
    } catch {
        log("[R*Could not open '\(url.absoluteString)': \(error.localizedDescription)*]")
    }
}
