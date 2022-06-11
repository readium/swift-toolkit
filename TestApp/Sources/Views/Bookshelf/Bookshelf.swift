//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct Bookshelf: View {
    
    @ObservedObject var viewModel: BookshelfViewModel
    @State private var showingSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                // TODO figure out what the best column layout is for phones and tablets
                if let books = viewModel.books {
                    let columns: [GridItem] = Array(repeating: .init(.adaptive(minimum: 170)), count: 2)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(books, id: \.self) { item in
                                BookCover(book: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bookshelf")
            .toolbar(content: toolbarContent)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingSheet) {
            AddBookSheet(showingSheet: $showingSheet) { url in
                // TODO validate the URL and import the book
            }
        }
    }
}

extension Bookshelf {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(.add) {
                showingSheet = true
            }
        }
    }
}

