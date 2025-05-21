//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import SwiftUI

// This file contains view model wrappers for fetching data from Repositories: Bookmarks and Highlights.
// It's not acceptable to fetch that data in a Swiftui View's constructor, so we need a reactive wrapper.

// MARK: - Highlights

final class HighlightsViewModel: ObservableObject, OutlineViewModelLoaderDelegate {
    typealias T = Highlight
    @Published var highlights = [Highlight]()

    private let bookId: Book.Id
    private let repository: HighlightRepository

    private lazy var loader: OutlineViewModelLoader<Highlight, HighlightsViewModel> = OutlineViewModelLoader(delegate: self)

    init(bookId: Book.Id, repository: HighlightRepository) {
        self.bookId = bookId
        self.repository = repository
    }

    func load() {
        loader.load()
    }

    func loadIfNeeded() {
        loader.loadIfNeeded()
    }

    var dataTask: AnyPublisher<[Highlight], Error> {
        repository.all(for: bookId)
    }

    func setLoadedValues(_ values: [Highlight]) {
        highlights = values
    }
}

// MARK: - Bookmarks

final class BookmarksViewModel: ObservableObject, OutlineViewModelLoaderDelegate {
    typealias T = Bookmark
    @Published var bookmarks = [Bookmark]()

    private let bookId: Book.Id
    private let repository: BookmarkRepository

    private lazy var loader: OutlineViewModelLoader<Bookmark, BookmarksViewModel> = OutlineViewModelLoader(delegate: self)

    init(bookId: Book.Id, repository: BookmarkRepository) {
        self.bookId = bookId
        self.repository = repository
    }

    func load() {
        loader.load()
    }

    func loadIfNeeded() {
        loader.loadIfNeeded()
    }

    var dataTask: AnyPublisher<[Bookmark], Error> {
        repository.all(for: bookId)
    }

    func setLoadedValues(_ values: [Bookmark]) {
        bookmarks = values
    }
}

// MARK: - Generic state management

private protocol OutlineViewModelLoaderDelegate: AnyObject {
    associatedtype T

    var dataTask: AnyPublisher<[T], Error> { get }
    func setLoadedValues(_ values: [T])
}

// This loader contains a state enum which can be used for expressive UI (loading progress, error handling etc). For this, status overlay view can be used (see https://stackoverflow.com/a/61858358/2567725).
private final class OutlineViewModelLoader<T, Delegate: OutlineViewModelLoaderDelegate> {
    weak var delegate: Delegate!
    private var state = State.ready

    enum State {
        case ready
        case loading(Combine.Cancellable)
        case loaded
        case error(Error)
    }

    init(delegate: Delegate) {
        self.delegate = delegate
    }

    func load() {
        assert(Thread.isMainThread)
        state = .loading(delegate.dataTask.sink(
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
                self.delegate.setLoadedValues(value)
            }
        ))
    }

    func loadIfNeeded() {
        assert(Thread.isMainThread)
        guard case .ready = state else { return }
        load()
    }
}
