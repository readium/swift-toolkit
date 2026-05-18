//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import OSLog
import SwiftUI

@main
struct PlaygroundApp: App {
    /// Shared store for publication files in the app's Documents directory.
    @StateObject private var documentRepository = DocumentRepository()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(documentRepository)
        }
    }
}

/// Root layout: a two-column split view with the document list in the sidebar
/// and a `PublicationView` in the detail column.
struct ContentView: View {
    /// The file URL selected in the sidebar, or `nil` when nothing is selected.
    @State private var selectedFile: URL?

    var body: some View {
        NavigationSplitView {
            DocumentList(selectedFile: $selectedFile)
        } detail: {
            if let selectedFile {
                PublicationView(file: selectedFile)
                    .id(selectedFile)

            } else {
                Text("No Publication Selected")
                    .font(.title2)
            }
        }
    }
}
