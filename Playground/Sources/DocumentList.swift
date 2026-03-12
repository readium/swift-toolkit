//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct DocumentList: View {
    @Binding var selectedFile: URL?

    @EnvironmentObject var documentRepository: DocumentRepository

    @State private var showFileImporter: Bool = false
    @State private var error: Error?

    var body: some View {
        List(selection: $selectedFile) {
            ForEach(documentRepository.documents, id: \.self) { file in
                Text(file.lastPathComponent)
                    .swipeActions(edge: .trailing) {
                        // We can't use `role: destructive` or `onDelete()`,
                        // because it will remove the item from the list even
                        // if the deletion fails.
                        Button("Delete") {
                            delete(file)
                        }
                        .tint(.red)
                    }
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

    private func add(file: URL) {
        do {
            try documentRepository.add(file: file)
        } catch {
            self.error = error
        }
    }

    private func delete(_ file: URL) {
        do {
            try documentRepository.remove(file)
        } catch {
            self.error = error
        }
    }
}
