import Foundation

struct Config {
    enum LogLevel: Int, Comparable {
        case debug, verbose, info

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        static func > (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue > rhs.rawValue
        }
    }

    var globalLogLevel = LogLevel.info

    var server = URL(string: "https://api.github.com/graphql")!

    var maxNodeCost = 10000
    var monochrome = false
    var dryRun = false

    static let emptyURL = URL(string: "http://github.com")!

    private static let versionNumbers = [1, 6, 0]
    let versionString = versionNumbers.map { String($0) }.joined(separator: ".")

    static func isNewer(_ version: String) -> Bool {
        let components = version
            .split(separator: ".")
            .compactMap { Int($0) }

        guard components.count == 3 else {
            return false
        }

        for check in versionNumbers.enumerated() {
            let v = check.element
            let i = check.offset
            if v < versionNumbers[i] {
                return true
            } else if v > versionNumbers[i] {
                return false
            }
        }

        return false
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
        get {
            if let d = try? Data(contentsOf: saveLocation.appendingPathComponent("token")) {
                return String(data: d, encoding: .utf8) ?? ""
            }
            return ""
        }
        set {
            let tokenFileURL = saveLocation.appendingPathComponent("token")
            try! newValue.data(using: .utf8)?.write(to: tokenFileURL)
            try! FileManager.default.setAttributes([.posixPermissions: NSNumber(0o600)], ofItemAtPath: tokenFileURL.path)
        }
    }

    var usingNewIds: Bool {
        get {
            let path = saveLocation.appendingPathComponent("using-new-ids").path
            return FileManager.default.fileExists(atPath: path)
        }
        set {
            let path = saveLocation.appendingPathComponent("using-new-ids").path
            if newValue {
                FileManager.default.createFile(atPath: path, contents: nil)
            } else {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    private func store(date: Date?, name: String) {
        var dateTickString: String?
        if let d = date { dateTickString = String(d.timeIntervalSince1970) }
        store(string: dateTickString, name: name)
    }

    private func fetchDate(name: String) -> Date? {
        if let dateString = fetchString(name: name), let dateTicks = TimeInterval(dateString) {
            return Date(timeIntervalSince1970: dateTicks)
        }
        return nil
    }

    private func store(string: String?, name: String) {
        let fileURL = saveLocation.appendingPathComponent(name)
        if let s = string {
            try! s.data(using: .utf8)?.write(to: fileURL)
        } else {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try! FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func fetchString(name: String) -> String? {
        if let d = try? Data(contentsOf: saveLocation.appendingPathComponent(name)) {
            return String(data: d, encoding: .utf8)
        }
        return nil
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
        let c = URLComponents(url: server, resolvingAgainstBaseURL: false)
        let f = FileManager.default
        let h = URL(string: "file://" + NSHomeDirectory())!
        let d = h.appendingPathComponent(".trailer", isDirectory: true).appendingPathComponent(c!.host!, isDirectory: true)
        if !f.fileExists(atPath: d.path) {
            try! f.createDirectory(at: d, withIntermediateDirectories: true, attributes: nil)
        }
        return d
    }
}

@MainActor
var config = Config()
