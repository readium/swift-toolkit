//
//  ContentView.swift
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

struct ContentView: View {
    var body: some View {
        TabView {
            BookshelfTab()
                .tabItem {
                    Label("Bookshelf", systemImage: "books.vertical.fill")
                }
            CatalogsTab()
                .tabItem {
                    Label("Catalogs", systemImage: "magazine.fill")
                }
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
