//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import R2Shared
import SwiftUI

class BookNavigatorHashableDestination: Hashable {
    static func == (lhs: BookNavigatorHashableDestination, rhs: BookNavigatorHashableDestination) -> Bool {
        return lhs.book.id == rhs.book.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(book.id)
    }
    
    let book: Book
    let publication: Publication
    
    init(book: Book, publication: Publication) {
        self.book = book
        self.publication = publication
    }
}

class BookshelfCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    
    func onBookOpened(book: Book, publication: Publication) {
        path.append(BookNavigatorHashableDestination(book: book, publication: publication))
    }
}


struct Bookshelf: View {
    @ObservedObject var coordinator = BookshelfCoordinator()
    
    let readerDependencies: ReaderDependencies
    @ObservedObject var bookOpener: BookOpener
    @State private var showingSheet = false
    @State private var books: [Book] = []
    
    @State private var curOpeningBookId: Book.Id = 0
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            VStack {
                // TODO figure out what the best column layout is for phones and tablets
                let columns: [GridItem] = [GridItem(.adaptive(minimum: Constant.bookCoverWidth + Constant.adaptiveGridDelta))]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(books, id: \.self) { book in
                            BookCover(
                                width: Constant.bookCoverWidth,
                                height: Constant.bookCoverHeight,
                                title: book.title,
                                authors: book.authors,
                                url: book.cover
                            )
                            .navigationDestination(for: BookNavigatorHashableDestination.self, destination: { destination in
                                readerView(model: destination)
                            })
                            .contextMenu {
                                bookCoverContextMenu(for: book)
                            }
                            .overlay(content: {
                                bookCoverProgressOverlay(for: book)
                            })
                            .onTapGesture {
                                bookCoverTapHandler(for: book)
                            }
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
    }
    
    func bookCoverTapHandler(for book: Book) {
        Task {
            let result = await bookOpener.openBook(book)
            switch result {
            case .success(let publication):
                coordinator.onBookOpened(book: book, publication: publication)
            case .failure(let error):
                print("BookOpener error \(error)")
            }
        }
    }
        
    @ViewBuilder func bookCoverProgressOverlay(for book: Book) -> some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .opacity(curOpeningBookId == book.id ? 1 : 0)
    }
    
    @ViewBuilder func bookCoverContextMenu(for book: Book) -> some View {
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
    
    @ViewBuilder func readerView(model: BookNavigatorHashableDestination) -> some View {
        let viewModel = NewReaderViewModel(book: model.book, publication: model.publication, readerDependencies: readerDependencies)
        NewReaderView(
            bookId: viewModel.book.id!,
            viewModel: viewModel
        )
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
