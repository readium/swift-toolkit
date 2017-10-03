//
//  LCPDatabase.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 10/2/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SQLite

enum LCPDatabaseError: Error {
}

final class LCPDatabase {
    /// Shared instance.
    public static let shared = LCPDatabase()

    /// Tables.
    let licenses: Licenses!
    let transactions: Transactions!

    private init() {
        do {
        var url = try FileManager.default.url(for: .libraryDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        
        url.appendPathComponent("lcpdatabase.sqlite")
        licenses = try Licenses.init(forDatabaseAt: url)
        transactions = try Transactions.init(forDatabaseAt: url)
        } catch {
            fatalError("Error initializing db.")
        }
    }
}

