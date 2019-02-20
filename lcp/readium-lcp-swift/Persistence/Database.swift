//
//  Database.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 10/2/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SQLite

final class Database {
    /// Shared instance.
    static let shared = Database()

    /// Connection.
    let connection: Connection
    /// Tables.
    let licenses: Licenses!
    let transactions: Transactions!

    private init() {
        do {
            var url = try FileManager.default.url(for: .libraryDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil, create: true)

            url.appendPathComponent("lcpdatabase.sqlite")
            connection = try Connection(url.absoluteString)
            licenses = Licenses(connection)
            transactions = Transactions(connection)
        } catch {
            fatalError("Error initializing db.")
        }
    }
}

extension Connection {
    
    var userVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
        set { try! run("PRAGMA user_version = \(newValue)") }
    }
    
}
