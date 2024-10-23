//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import GRDB
import SwiftUI

// @main
/// The main function and serves as the app's entry
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
