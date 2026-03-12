//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import OSLog
import SwiftUI

@main
struct PlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    /// Watches the content of the Documents/ folder.
    @StateObject private var watcher = DirectoryWatcher(
        url: FileManager.default.documentDirectory
    )

    var body: some View {
        List(watcher.files, id: \.self) { file in
            Text(file.lastPathComponent)
        }
    }
}
