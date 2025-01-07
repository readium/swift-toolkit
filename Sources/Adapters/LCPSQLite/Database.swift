//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SQLite

final class Database {
    /// Shared instance.
    static let shared: Swift.Result<Database, Error> = {
        do {
            return try .success(Database())
        } catch {
            return .failure(error)
        }
    }()

    let connection: Connection

    private init() throws {
        var url = try FileManager.default.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        url.appendPathComponent("lcpdatabase.sqlite")
        connection = try Connection(url.absoluteString)
    }
}

extension Connection {
    var userVersion: Int32 {
        get { Int32(try! scalar("PRAGMA user_version") as! Int64) }
        set { try! run("PRAGMA user_version = \(newValue)") }
    }
}
