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

	var latestSyncDate: Date? {
		get {
			if let d = try? Data(contentsOf: saveLocation.appendingPathComponent("latest-sync-date")),
				let dateString = String(data:d, encoding: .utf8),
				let dateTicks = TimeInterval(dateString) {

				return Date(timeIntervalSince1970: dateTicks)
			}
			return nil
		}
		set {
			let fileURL = saveLocation.appendingPathComponent("latest-sync-date")
			if let n = newValue {
				let dateTickString = String(n.timeIntervalSince1970)
				try! dateTickString.data(using: .utf8)?.write(to: fileURL)
			} else {
				if FileManager.default.fileExists(atPath: fileURL.path) {
					try! FileManager.default.removeItem(at: fileURL)
				}
			}
		}
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
