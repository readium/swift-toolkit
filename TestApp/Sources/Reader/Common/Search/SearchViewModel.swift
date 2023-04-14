//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import ReadiumOPDS

// See https://github.com/readium/r2-testapp-swift/discussions/402
final class SearchViewModel: ObservableObject {
    enum State {
        // Empty state / waiting for a search query
        case empty
        // Starting a new search, after calling `cancellable = publication.search(...)`
        case starting(Cancellable)
        // Waiting state after receiving a SearchIterator and waiting for a next() call
        case idle(SearchIterator)
        // Loading the next page of result
        case loadingNext(SearchIterator, Cancellable)
        // We reached the end of the search results
        case end
        // An error occurred, we need to show it to the user
        case failure(LocalizedError)
    }

    @Published private(set) var state: State = .empty
    @Published private(set) var results: [Locator] = []
    @Published private(set) var query: String = ""
    @Published var selectedLocator: Locator?
    var selectedIndex: Int?

    func selectSearchResultCell(locator: Locator?, index: Int) {
        selectedIndex = index
        selectedLocator = locator
    }

    private var publication: Publication

    init(publication: Publication) {
        self.publication = publication
    }

    /// Starts a new search with the given query.
    func search(with query: String) {
        self.query = query
        cancelSearch()

        let cancellable = publication._search(query: query) { result in
            switch result {
            case let .success(iterator):
                self.state = .idle(iterator)
                self.loadNextPage()

            case let .failure(error):
                self.state = .failure(error)
            }
        }

        state = .starting(cancellable)
    }

    /// Loads the next page of search results.
    /// Typically, this would be called when the user scrolls towards the end of the results table view.
    func loadNextPage() {
        guard case let .idle(iterator) = state else {
            return
        }

        let cancellable = iterator.next { result in
            switch result {
            case let .success(collection):
                if let collection = collection {
                    self.results.append(contentsOf: collection.locators)
                    self.state = .idle(iterator)
                } else {
                    self.state = .end
                }

            case let .failure(error):
                self.state = .failure(error)
            }
        }

        state = .loadingNext(iterator, cancellable)
    }

    /// Cancels any on-going search and clears the results.
    func cancelSearch() {
        switch state {
        case let .idle(iterator):
            iterator.close()

        case let .loadingNext(iterator, cancellable):
            iterator.close()
            cancellable.cancel()

        default:
            break
        }

        results.removeAll()
        state = .empty
    }
}
