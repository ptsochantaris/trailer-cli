//
//  Globals.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation
import Dispatch

let emptyURL = URL(string: "http://github.com")!

enum LogLevel: Int {
	case debug = 0, verbose = 1, info = 2
}

var globalLogLevel = LogLevel.info

func log(level: LogLevel = .info, indent: Int = 0, _ message: @autoclosure ()->String = "", unformatted: Bool = false) {
	if globalLogLevel.rawValue > level.rawValue { return }
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
