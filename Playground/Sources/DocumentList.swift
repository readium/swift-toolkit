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

    private func add(file: URL) {
        do {
            try documentRepository.add(file: file)
        } catch {
            self.error = UserError(error)
        }
    }

    private func delete(atOffsets offsets: IndexSet) {
        do {
            try documentRepository.remove(atOffsets: offsets)
        } catch {
            self.error = UserError(error)
        }
    }
}
