//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import Combine

// This file contains view model wrappers for fetching data from Repositories: Bookmarks and Highlights.
// It's not acceptable to fetch that data in a Swiftui View's constructor, so we need a reactive wrapper.
// We use a pattern described here: https://stackoverflow.com/a/61858358/2567725
// Each view model contains a state enum which can be used for expressive UI (loading progress, error handling etc). For this, status overlay view can be used (see the link).

// MARK: - Highlights

final class HighlightsViewModel: ObservableObject {
    private let bookId: Book.Id
    private let highlightRepository: HighlightRepository
    
    @Published var highlights = [Highlight]()
    @Published var state = State.ready
    
    init(bookId: Book.Id, highlightRepository: HighlightRepository) {
        self.bookId = bookId
        self.highlightRepository = highlightRepository
    }

    enum State {
        case ready
        case loading(Combine.Cancellable)
        case loaded
        case error(Error)
    }

    var dataTask: AnyPublisher<[Highlight], Error> {
        self.highlightRepository.all(for: bookId)
    }

    func load() {
        assert(Thread.isMainThread)
        self.state = .loading(self.dataTask.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case let .failure(error):
                    self.state = .error(error)
                }
            },
            receiveValue: { value in
                self.state = .loaded
                self.highlights = value
            }
        ))
    }

    func loadIfNeeded() {
        assert(Thread.isMainThread)
        guard case .ready = self.state else { return }
        self.load()
    }
}

// MARK: - Bookmarks

final class BookmarksViewModel: ObservableObject {
    private let bookId: Book.Id
    private let bookmarkRepository: BookmarkRepository
    
    @Published var bookmarks = [Bookmark]()
    @Published var state = State.ready
    
    init(bookId: Book.Id, bookmarkRepository: BookmarkRepository) {
        self.bookId = bookId
        self.bookmarkRepository = bookmarkRepository
    }
    
    enum State {
        case ready
        case loading(Combine.Cancellable)
        case loaded
        case error(Error)
    }

    var dataTask: AnyPublisher<[Bookmark], Error> {
        self.bookmarkRepository.all(for: bookId)
    }

    func load() {
        assert(Thread.isMainThread)
        self.state = .loading(self.dataTask.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case let .failure(error):
                    self.state = .error(error)
                }
            },
            receiveValue: { value in
                self.state = .loaded
                self.bookmarks = value
            }
        ))
    }

    func loadIfNeeded() {
        assert(Thread.isMainThread)
        guard case .ready = self.state else { return }
        self.load()
    }
}
