//
//  Config.swift
//  trailer
//
//  Created by Paul Tsochantaris on 21/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Config {
	var server: URL = URL(string: "https://api.github.com/graphql")!

	var pageSize = 100

	var monochrome = false

	let versionMajor = 0
	let versionMinor = 9
	let versionPatch = 5
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
		let fileURL = saveLocation.appendingPathComponent(name)
		if let d = date {
			let dateTickString = String(d.timeIntervalSince1970)
			try! dateTickString.data(using: .utf8)?.write(to: fileURL)
		} else {
			if FileManager.default.fileExists(atPath: fileURL.path) {
				try! FileManager.default.removeItem(at: fileURL)
			}
		}
	}

	private func fetchDate(name: String) -> Date? {
		if let d = try? Data(contentsOf: saveLocation.appendingPathComponent(name)),
			let dateString = String(data:d, encoding: .utf8),
			let dateTicks = TimeInterval(dateString) {

			return Date(timeIntervalSince1970: dateTicks)
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
