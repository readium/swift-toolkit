//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct Bookshelf: View {
    let bookRepository: BookRepository
    let reader: (Book) -> Reader

    @State private var showingSheet = false
    @State private var books: [Book] = []

    var body: some View {
        NavigationStack {
            VStack {
                // TODO: figure out what the best column layout is for phones and tablets
                let columns: [GridItem] = [GridItem(.adaptive(minimum: Constant.bookCoverWidth + Constant.adaptiveGridDelta))]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(books, id: \.self) { book in
                            NavigationLink(value: book) {
                                BookCover(title: book.title, authors: book.authors, url: book.cover?.url)
                            }
                            .buttonStyle(.plain)
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
            .navigationDestination(for: Book.self) { book in
                reader(book)
            }
            .toolbar(content: toolbarContent)
        }
        .sheet(isPresented: $showingSheet) {
            AddBookSheet { url in
                // TODO: validate the URL and import the book
            }
        }
    }
}

extension Bookshelf {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(.add, action: {
                showingSheet = true
            })
        }
    }
}
