import Foundation
import TrailerQL
#if os(Windows)
    import WinSDK
#endif

@main
@MainActor
struct MainApp {
    static func main() async {
        Task { @LogActor in
            TQL.debugLog = { message in
                Task { @MainActor in
                    log(level: .debug, indent: 0, message)
                }
            }
        }

        let app = MainApp()
        try? await app.go()
    }

    private func setupConsole() {
        config.monochrome = CommandLine.argument(exists: "-mono")
        config.dryRun = CommandLine.argument(exists: "-dryrun")

        #if os(Windows)
            if !config.monochrome {
                let hOut = GetStdHandle(STD_OUTPUT_HANDLE)
                var dwMode: DWORD = 0

                guard hOut != INVALID_HANDLE_VALUE,
                      GetConsoleMode(hOut, &dwMode)
                else {
                    config.monochrome = true
                    return
                }

                dwMode |= DWORD(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
                guard SetConsoleMode(hOut, dwMode) else {
                    config.monochrome = true
                    return
                }
            }
        #endif
    }

    private func go() async throws {
        setupConsole()

        if CommandLine.argument(exists: "-version") {
            log("[!Version [*\(config.versionString)*]!]")
            await Actions.checkForUpdates(reportError: true, alwaysCheck: true)
            log()
            exit(0)
        }

        if let s = URL(string: CommandLine.value(for: "-server") ?? "https://api.github.com/graphql"), s.host != nil {
            config.server = s
        } else {
            Actions.reportAndExit(message: "Provided server URL is invalid")
        }

        if let p = CommandLine.value(for: "-max-node-cost") {
            if let i = Int(p) {
                if i < 0 {
                    Actions.reportAndExit(message: "Provided max node cost '\(p)' must be a positive number")
                } else {
                    config.maxNodeCost = i
                }
            } else {
                Actions.reportAndExit(message: "Provided max node cost '\(p)' isn't a number")
            }
        }

        if CommandLine.argument(exists: "-debug") {
            config.globalLogLevel = .debug
            log("Will be verbose [*(debug)*]")
        } else if CommandLine.argument(exists: "-v") {
            config.globalLogLevel = .verbose
            log("Will be verbose")
        }

        let listSequence = CommandLine.sequence(starting: "list")
        let openSequence = CommandLine.sequence(starting: "open")
        let showSequence = CommandLine.sequence(starting: "show")
        let updateSequence = CommandLine.sequence(starting: "update")
        let configSequence = CommandLine.sequence(starting: "config")
        let actionSequence = listSequence ?? openSequence ?? showSequence ?? updateSequence ?? configSequence

        let actionString = CommandLine.argument(matching: "reset")
            ?? actionSequence?.first
            ?? CommandLine.argument(matching: "stats")
            ?? ""

        let actionDetected = Action(rawValue: actionString)

        if let t = CommandLine.value(for: "-token") {
            if t.isEmpty {
                Actions.reportAndExit(message: "Parameter -token requires a token value")
            } else if t == "display" {
                if config.token.isEmpty {
                    log("Token for server [*\(config.server.absoluteString)*] isn't set")
                } else {
                    log("Token for server [*\(config.server.absoluteString)*] is [*\(config.token)*]")
                }
                if actionDetected == nil {
                    exit(0)
                }
            } else if t == "test" {
                if config.token.isEmpty {
                    log("Token for server [*\(config.server.absoluteString)*] isn't set")
                } else {
                    try await Actions.testToken()
                }
                if actionDetected == nil {
                    exit(0)
                }
            } else if let token = CommandLine.value(for: "-token", keepCase: true) {
                config.token = token
                log("Token for server [*\(config.server.absoluteString)*] has been set to [*\(token)*]")
                if actionDetected == nil {
                    exit(0)
                }
            }
        }

        if actionDetected == .update {
            if config.token.isEmpty {
                Actions.reportAndExit(message: "You do not have an access token configured for this server, use the '-token' option to add one.")
            }
        }

        guard let action = actionDetected else {
            Actions.reportAndExit(message: nil)
        }

        extendStackSizeIfNeeded()

        try await Actions.performAction(action, listSequence: actionSequence)
    }

    // With thanks to: https://stackoverflow.com/questions/2275550/change-stack-size-for-a-c-application-in-linux-during-compilation-with-gnu-com#2284691
    private func extendStackSizeIfNeeded() {
        #if os(Windows)
        // is done with editbin /stack:24117248
        #else
            let kStackSize: rlim_t = 32 * 1024 * 1024
            var rl = rlimit()
            #if os(Linux)
                let s = Int32(RLIMIT_STACK.rawValue)
            #else
                let s = RLIMIT_STACK
            #endif
            if getrlimit(s, &rl) == 0 {
                if rl.rlim_cur < kStackSize {
                    rl.rlim_cur = kStackSize
                    setrlimit(s, &rl)
                }
            }
        #endif
    }
}
