//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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
        get { Int32(try! scalar("PRAGMA user_version") as! Int64) }
        set { try! run("PRAGMA user_version = \(newValue)") }
    }
}
