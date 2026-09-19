import Foundation

struct Config {
    /// Ordered least to most severe; `Comparable` is synthesised from the declaration order.
    enum LogLevel: Comparable {
        case debug, verbose, info
    }

    var globalLogLevel = LogLevel.info

    var server = URL(string: "https://api.github.com/graphql")!

    var maxNodeCost = 10000
    var monochrome = false
    var dryRun = false

    static let emptyURL = URL(string: "http://github.com")!

    private static let versionNumbers = [1, 7, 0]
    let versionString = versionNumbers.map { String($0) }.joined(separator: ".")

    /// True when `version` (as reported by the releases API) is later than the version we are built as.
    static func isNewer(_ version: String) -> Bool {
        let components = version
            .split(separator: ".")
            .compactMap { Int($0) }

        guard components.count == versionNumbers.count else {
            return false
        }

        return versionNumbers.lexicographicallyPrecedes(components)
    }

    var httpHeaders: [(String, String)] {
        #if DEBUG
            let variant = "Development"
        #else
            let variant = "Release"
        #endif

        #if os(macOS)
            let OS = "macOS"
        #elseif os(Linux)
            let OS = "Linux"
        #elseif os(Windows)
            let OS = "Windows"
        #endif

        return [
            ("Authorization", "bearer \(token)"),
            ("User-Agent", "Trailer-CLI-v\(versionString)-\(OS)-\(variant)"),
            ("X-Github-Next-Global-ID", usingNewIds ? "1" : "0")
        ]
    }

    var myUser: User? {
        didSet {
            if let u = myUser {
                myLogin = "@\(u.login)"
            } else {
                myLogin = ""
            }
        }
    }

    var myLogin = ""

    var token: String {
        get { fetchString(name: "token") ?? "" }
        set {
            let tokenFileURL = saveLocation.appending(path: "token")
            do {
                try Data(newValue.utf8).write(to: tokenFileURL)
                try FileManager.default.setAttributes([.posixPermissions: NSNumber(0o600)], ofItemAtPath: tokenFileURL.path)
            } catch {
                log("[R*Could not store the token: \(error.localizedDescription)*]")
            }
        }
    }

    var usingNewIds: Bool {
        get {
            let path = saveLocation.appending(path: "using-new-ids").path
            return FileManager.default.fileExists(atPath: path)
        }
        set {
            let path = saveLocation.appending(path: "using-new-ids").path
            if newValue {
                if !FileManager.default.createFile(atPath: path, contents: nil) {
                    log("[R*Could not create marker file at '\(path)'*]")
                }
            } else {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    private func store(date: Date?, name: String) {
        store(string: date.map { String($0.timeIntervalSince1970) }, name: name)
    }

    private func fetchDate(name: String) -> Date? {
        if let dateString = fetchString(name: name), let dateTicks = TimeInterval(dateString) {
            return Date(timeIntervalSince1970: dateTicks)
        }
        return nil
    }

    private func store(string: String?, name: String) {
        let fileURL = saveLocation.appending(path: name)
        do {
            if let string {
                try Data(string.utf8).write(to: fileURL)
            } else if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            log("[R*Could not store '\(name)': \(error.localizedDescription)*]")
        }
    }

    private func fetchString(name: String) -> String? {
        guard let data = try? Data(contentsOf: saveLocation.appending(path: name)) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    var latestSyncDate: Date? {
        get { fetchDate(name: "latest-sync-date") }
        set { store(date: newValue, name: "latest-sync-date") }
    }

    var lastUpdateCheckDate: Date {
        get { fetchDate(name: "latest-update-check-date") ?? .distantPast }
        set { store(date: newValue, name: "latest-update-check-date") }
    }

    var defaultRepoVisibility: RepoVisibility {
        get {
            if let s = fetchString(name: "default-repo-visibility"), let v = RepoVisibility(rawValue: s) {
                return v
            }
            return RepoVisibility.visible
        }
        set { store(string: newValue.rawValue, name: "default-repo-visibility") }
    }

    var totalQueryCosts = 0
    var totalApiRemaining = Int.max

    var saveLocation: URL {
        guard let host = server.host() else {
            Actions.reportAndExit(message: "Server URL '\(server.absoluteString)' has no host component")
        }
        let directory = URL.homeDirectory
            .appending(path: ".trailer", directoryHint: .isDirectory)
            .appending(path: host, directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                Actions.reportAndExit(message: "Could not create '\(directory.path)': \(error.localizedDescription)")
            }
        }
        return directory
    }
}

var config = Config()
