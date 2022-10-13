//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import R2Shared
import SwiftUI

struct Bookshelf: View {
    let readerDependencies: ReaderDependencies
    @ObservedObject var bookOpener: BookOpener
    @State private var showingSheet = false
    @State private var books: [Book] = []
    
    @State private var curOpeningBookId: Book.Id = 0
    @State private var lastOpenedBookTag: Book.Id?
    @State private var viewModelToOpen: NewReaderViewModel?
    
    var body: some View {
        VStack {
            // TODO figure out what the best column layout is for phones and tablets
            let columns: [GridItem] = [GridItem(.adaptive(minimum: Constant.bookCoverWidth + Constant.adaptiveGridDelta))]
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(books, id: \.self) { book in
                        NavigationLink(
                            destination: readerView(),
                            tag: book.id!,
                            selection: self.$lastOpenedBookTag
                        ) {
                            BookCover(
                                width: Constant.bookCoverWidth,
                                height: Constant.bookCoverHeight,
                                title: book.title,
                                authors: book.authors,
                                url: book.cover
                            )
                            .contextMenu {
                                Button(
                                    role: .destructive,
                                    action: {
                                        let bookRemover = BookRemover(readerDependencies: readerDependencies)
                                        Task {
                                            await bookRemover.remove(book)
                                        }
                                    }) {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                            .overlay(content: {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .opacity(curOpeningBookId == book.id ? 1 : 0)
                            })
                            .onTapGesture {
                                Task {
                                    let result = await bookOpener.openBook(book)
                                    switch result {
                                    case .success(let publication):
                                        viewModelToOpen = NewReaderViewModel(
                                            book: book,
                                            publication: publication,
                                            readerDependencies: readerDependencies
                                        )
                                        lastOpenedBookTag = book.id
                                    case .failure(let error):
                                        print("BookOpener error \(error)")
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onReceive(readerDependencies.books.all()) {
                    books = $0
                }
            }
            
        }
        .navigationTitle("Bookshelf")
        .toolbar(content: toolbarContent)
    }
    
    @ViewBuilder func readerView() -> some View {
        if viewModelToOpen != nil {
            NewReaderView(
                viewModel: viewModelToOpen!
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

enum Constant {
    static let bookCoverWidth: Double = 130
    static let bookCoverHeight: Double = 200
    static let adaptiveGridDelta: Double = 8 // TODO: what is it?
}
