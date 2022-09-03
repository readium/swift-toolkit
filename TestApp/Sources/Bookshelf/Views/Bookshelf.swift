//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import R2Shared
import SwiftUI

struct Bookshelf: View {
    
    let bookRepository: BookRepository
    @ObservedObject var bookOpener: BookOpener
    @State private var showingSheet = false
    @State private var books: [Book] = []
    
    var body: some View {
        VStack {
            // TODO figure out what the best column layout is for phones and tablets
            let columns: [GridItem] = [GridItem(.adaptive(minimum: 150 + 8))]
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(books, id: \.self) { book in
                        NavigationLink(
                            destination: readerView(),
                            tag: book.id!,
                            selection: self.$bookOpener.openedBookTag
                        ) {
                            BookCover(
                                title: book.title,
                                authors: book.authors,
                                url: book.cover
                            )
                            .overlay(content: {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .opacity(bookOpener.curOpeningBookId == book.id ? 1 : 0)
                            })
                            .onTapGesture {
                                _ = bookOpener.openBookTask(book)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onReceive(bookRepository.all()) {
                    books = $0
                }
            }
            
        }
        .navigationTitle("Bookshelf")
        .toolbar(content: toolbarContent)
        .sheet(isPresented: $showingSheet) {
            AddBookSheet(showingSheet: $showingSheet) { url in
                // TODO validate the URL and import the book with "bookOpener"
            }
        }
    }
    
    @ViewBuilder func readerView() -> some View {
        if bookOpener.openedBook != nil {
            NewReaderView(
                viewModel: bookOpener.newReaderViewModel
            )
        } else {
            Text("no book")
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
