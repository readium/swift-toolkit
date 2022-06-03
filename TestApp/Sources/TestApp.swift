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

@main
struct TestApp: App {
    let container = try! Container()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                container.bookshelf()
                    .tabItem {
                        Label("Bookshelf", systemImage: "books.vertical.fill")
                    }
                container.catalogs()
                    .tabItem {
                        Label("Catalogs", systemImage: "magazine.fill")
                    }
                container.about()
                    .tabItem {
                        Label("About", systemImage: "info.circle.fill")
                    }
            }
        }
    }
}
