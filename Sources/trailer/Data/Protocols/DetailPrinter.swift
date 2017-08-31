//
//  DetailPrinter.swift
//  trailer
//
//  Created by Paul Tsochantaris on 28/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol DetailPrinter {
    var createdAt: Date { get set }
    func printDetails()
    func printSummaryLine()
}
