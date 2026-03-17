//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import OSLog
import SwiftUI

@main
struct PlaygroundApp: App {
    @StateObject private var documentRepository = DocumentRepository()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(documentRepository)
        }
    }
}

struct ContentView: View {
    @State private var selectedFile: URL?

    var body: some View {
        NavigationSplitView {
            DocumentList(selectedFile: $selectedFile)
        } detail: {
            if let selectedFile {
                PublicationView(file: selectedFile)
                    .id(selectedFile)

            } else {
                Text("No file selected")
                    .font(.title)
            }
        }
    }
}
