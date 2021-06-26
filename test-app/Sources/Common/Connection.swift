//
//  Connection.swift
//  r2-testapp-swift
//
//  Created by Aferdita Muriqi on 4/7/19.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SQLite

extension Connection {
    
    public var userVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
        set { try! run("PRAGMA user_version = \(newValue)") }
    }
    
    /// FIXME: Used to fix a crash with SQLite.swift pre Xcode 10.2.1.
    /// We can't use the version 0.11.6 before Xcode 10.2, but the version 0.11.5 crashes on Xcode 10.2 (ie. https://github.com/stephencelis/SQLite.swift/issues/888)
    func count(_ expressible: Expressible) throws -> Int64 {
        let sql = "SELECT COUNT(*) FROM (\(expressible.asSQL())) AS countable;"
        return (try scalar(sql) as? Int64) ?? 0
    }
    
}

