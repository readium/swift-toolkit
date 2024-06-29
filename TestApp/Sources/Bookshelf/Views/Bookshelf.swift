//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct Bookshelf: View {
    let bookRepository: BookRepository

    @State private var showingSheet = false
    @State private var books: [Book] = []

    var body: some View {
        NavigationView {
            VStack {
                // TODO: figure out what the best column layout is for phones and tablets
                let columns: [GridItem] = [GridItem(.adaptive(minimum: 150 + 8))]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(books, id: \.self) { book in
                            BookCover(title: book.title, authors: book.authors, url: book.cover?.url)
                        }
                    }
                    // TODO: handle error
                    .onReceive(bookRepository.all()
                        .replaceError(with: [])
                    ) { books in
                        self.books = books
                    }
                }
            }
            .navigationTitle("Bookshelf")
            .toolbar(content: toolbarContent)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingSheet) {
            AddBookSheet(showingSheet: $showingSheet) { _ in
                // TODO: validate the URL and import the book
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
