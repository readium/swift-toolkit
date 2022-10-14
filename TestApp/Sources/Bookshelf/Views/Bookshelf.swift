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

/// Aims to work in a background async context, unless "@MainActor" specified
/// Tried to change "class -> actor", but got "Actor-isolated property can not be mutated from the main actor"
class BookshelfCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var curOpeningBookId: Book.Id?
    let bookOpener: BookOpener
    private var openBookTask: Task<Void, Never>?
    
    init(bookOpener: BookOpener) {
        self.bookOpener = bookOpener
    }
    
    /// this is for the navigation
    @MainActor private func onBookOpened(book: Book, publication: Publication) {
        path.append(BookNavigatorHashableDestination(book: book, publication: publication))
    }
    
    func bookCoverTapHandler(for book: Book) {
        cancelOpeningTasks()
        openBookTask = Task {
            await setOpeningBookId(book.id)
            
            let result = await bookOpener.openBook(book)
            
            do {
                try Task.checkCancellation()
            } catch {
                await setOpeningBookId(nil)
                // stop silently
                return
            }
            
            switch result {
            case .success(let publication):
                await onBookOpened(book: book, publication: publication)
            case .failure(let error):
                print("BookOpener error \(error)")
            }
            
            await setOpeningBookId(nil)
        }
    }
    
    /// this is for showing a progress view
    @MainActor private func setOpeningBookId(_ id: Book.Id?) {
        curOpeningBookId = id
    }
    
    func cancelOpeningTasks() {
        openBookTask?.cancel()
    }
}


struct Bookshelf: View {
    @ObservedObject var coordinator: BookshelfCoordinator
    let readerDependencies: ReaderDependencies
    @State private var showingSheet = false
    @State private var books: [Book] = []
    
    init(readerDependencies: ReaderDependencies, bookOpener: BookOpener) {
        self.readerDependencies = readerDependencies
        self.coordinator = BookshelfCoordinator(bookOpener: bookOpener)
    }
    
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
                                coordinator.bookCoverTapHandler(for: book)
                            }
                        }
                    }
                    .onReceive(readerDependencies.books.all()) {
                        books = $0
                    }
                }
                .onDisappear {
                    coordinator.cancelOpeningTasks()
                }
            }
            .navigationTitle("Bookshelf")
            .toolbar(content: toolbarContent)
        }
    }
    
    @ViewBuilder func bookCoverProgressOverlay(for book: Book) -> some View {
        if coordinator.curOpeningBookId == book.id {
            ZStack {
                Color(white: 0, opacity: 0.75)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(2)
            }
                
        } else {
            EmptyView()
        }
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
