//
//  Config.swift
//  trailer
//
//  Created by Paul Tsochantaris on 21/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Config {
	var server = URL(string: "https://api.github.com/graphql")!

	var pageSize = 100

	var monochrome = false

	let versionMajor = 1
	let versionMinor = 0
	let versionPatch = 2
	var versionString: String {
		return [versionMajor, versionMinor, versionPatch].map { String($0) }.joined(separator: ".")
	}

	func isNewer(_ version: String) -> Bool {
		var local = [0, 0, 0]
		let components = version.split(separator: ".")
		for i in 0 ..< components.count {
			if let n = Int(String(components[i])) {
				local[i] = n
			}
		}
		
		if versionMajor < local[0] {
			return true
		} else if versionMajor > local[0] {
			return false
		}

		if versionMinor < local[1] {
			return true
		} else if versionMinor > local[1] {
			return false
		}

		if versionPatch < local[2] {
			return true
		} else if versionPatch > local[2] {
			return false
		}

		return false
	}

	var httpHeaders: [String: String] {
		#if DEBUG
			let variant = "Development"
		#else
			let variant = "Release"
		#endif

		#if os(OSX)
			let OS = "macOS"
		#elseif os(Linux)
			let OS = "Linux"
		#endif

		return [
			"Authorization": "bearer \(token)",
			"User-Agent": "Trailer-CLI-v\(versionString)-\(OS)-\(variant)"
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

	var myLogin: String = ""

	var token: String {
		get {
			if let d = try? Data(contentsOf: saveLocation.appendingPathComponent("token")) {
				return String(data:d, encoding: .utf8) ?? ""
			}
			return ""
		}
		set {
			try! newValue.data(using: .utf8)?.write(to: saveLocation.appendingPathComponent("token"))
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
		get { return fetchDate(name: "latest-sync-date") }
		set { store(date: newValue, name: "latest-sync-date") }
	}

	var lastUpdateCheckDate: Date {
		get { return fetchDate(name: "latest-update-check-date") ?? .distantPast }
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

var config = Config()
