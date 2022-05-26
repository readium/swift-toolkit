//
//  TestApp.swift
//  TestApp
//
//  Created by Steven Zeck on 5/15/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import SwiftUI
import GRDB
import GRDBQuery

//@main
struct testApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environment(\.db, try! Database(file: Paths.library.appendingPathComponent("database.db")))
        }
    }
}

private struct DatabaseKey: EnvironmentKey {
    static let defaultValue = Database.empty()
}

extension EnvironmentValues {
    var db: Database {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}

extension Query where Request.DatabaseContext == Database {
    init(_ request: Request) {
        self.init(request, in: \.db)
    }
}
