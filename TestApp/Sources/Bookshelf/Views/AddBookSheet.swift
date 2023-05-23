//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

enum AddBookSheetError: Error {
    case invalidURLString
    case unknown(error: Error)
}

struct AddBookSheet: View {
    // For iOS 15, we can use @Environment(\.dismiss)
    @Binding var showingSheet: Bool
    var completion: (Result<URL, AddBookSheetError>) -> Void
    
    @State var url1: String = ""
    @State var url2: URL?
    @State private var showingBookPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Button {
                    showingBookPicker = true
                } label: {
                    Text("From a filesystem")
                }
                
                TextField("URL", text: $url1)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            .navigationBarTitle("Add a Book")
            .toolbar(content: toolbarContent)
            .sheet(isPresented: $showingBookPicker) {
                BookImporterView(choosenURL: $url2, completion: { resultURL in
                    if case .success(let url) = resultURL {
                        completion(.success(url))
                    }
                    showingSheet = false
                })
            }
        }
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(.cancel) {
                showingSheet = false
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(.save) {
                if let url = URL(string: url1) {
                    completion(.success(url))
                } else {
                    completion(.failure(.invalidURLString))
                }
                showingSheet = false
            }
            .disabled(url1.isEmpty)
        }
    }
}
