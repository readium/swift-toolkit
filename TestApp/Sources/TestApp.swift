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
            ContentView().environment(\.dbQueue, try! DatabaseQueue(path: Paths.library.appendingPathComponent("database.db").path))
        }
    }
}

private struct DatabaseQueueKey: EnvironmentKey {
    static var defaultValue: DatabaseQueue {
        // FIXME this is bad
        try! Database(file: Paths.library.appendingPathComponent("database.db"))
        return DatabaseQueue()
    }
}

extension EnvironmentValues {
    var dbQueue: DatabaseQueue {
        get { self[DatabaseQueueKey.self] }
        set { self[DatabaseQueueKey.self] = newValue }
    }
}

extension Query where Request.DatabaseContext == DatabaseQueue {
    init(_ request: Request) {
        self.init(request, in: \.dbQueue)
    }
}
