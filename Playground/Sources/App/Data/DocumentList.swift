//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// Sidebar list of publication files stored in the app's Documents directory.
///
/// Provides a toolbar button to import new files via the system file picker,
/// handles files opened from other apps via `onOpenURL`, and supports swipe-to-
/// delete.
struct DocumentList: View {
    /// The currently selected file URL, shared with the detail pane.
    @Binding var selectedFile: URL?

    /// Injected store that tracks the Documents directory.
    @EnvironmentObject var documentRepository: DocumentRepository

    /// Controls whether the system file picker sheet is shown.
    @State private var showFileImporter: Bool = false

    /// Holds the last error to be displayed in an alert.
    @State private var error: UserError?

    var body: some View {
        List(selection: $selectedFile) {
            ForEach(documentRepository.documents, id: \.self) { file in
                Text(file.lastPathComponent)
            }
            .onDelete {
                delete(atOffsets: $0)
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showFileImporter = true
                }) {
                    Image(systemName: "document.badge.plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: DocumentTypes.main.supportedUTTypes
        ) { result in
            add(file: try! result.get())
        }
        .onOpenURL {
            add(file: $0)
        }
        .alert(error: $error)
    }

    /// Copies `file` into the Documents/ directory via the repository.
    private func add(file: URL) {
        do {
            try documentRepository.add(file: file)
        } catch {
            self.error = UserError(error)
        }
    }

    /// Deletes the files at `offsets`.
    private func delete(atOffsets offsets: IndexSet) {
        do {
            for file in documentRepository.get(atOffsets: offsets) {
                try documentRepository.remove(file)

                if selectedFile == file {
                    selectedFile = nil
                }
            }

        } catch {
            self.error = UserError(error)
        }
    }
}
