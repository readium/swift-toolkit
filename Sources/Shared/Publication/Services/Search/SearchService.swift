//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias SearchServiceFactory = (PublicationServiceContext) -> SearchService?

/// Provides a way to search terms in a publication.
public protocol SearchService: PublicationService {
    /// Default value for the search options of this service.
    ///
    /// If an option does not have a value, it is not supported by the service.
    var options: SearchOptions { get }

    /// Starts a new search through the publication content, with the given `query`.
    /// If an option is nil when calling search(), its value is assumed to be the default one.
    @discardableResult
    func search(query: String, options: SearchOptions?) async -> SearchResult<SearchIterator>
}

/// Iterates through search results.
public protocol SearchIterator: AnyObject, Closeable {
    /// Number of matches for this search, if known.
    ///
    /// Depending on the search algorithm, it may not be possible to know the result count until reaching the end of the
    /// publication.
    ///
    /// The count might be updated after each call to `next()`.
    var resultCount: Int? { get }

    /// Retrieves the next page of results.
    ///
    /// Returns nil when reaching the end of the publication, or an error in case of failure.
    @discardableResult
    func next() async -> SearchResult<LocatorCollection?>
}

public extension SearchIterator {
    /// Iterates over all the search results, calling the given `block` for each page.
    @discardableResult
    func forEach(_ block: @escaping (LocatorCollection) -> Void) async -> SearchResult<Void> {
        func next() async -> SearchResult<Void> {
            await self.next().asyncFlatMap { locators in
                if let locators = locators {
                    block(locators)
                    return await next()
                } else {
                    return .success(())
                }
            }
        }

        return await next()
    }
}

/// Holds the available search options and their current values.
public struct SearchOptions: Hashable {
    /// Whether the search will differentiate between capital and lower-case letters.
    public var caseSensitive: Bool?

    /// Whether the search will differentiate between letters with accents or not.
    public var diacriticSensitive: Bool?

    /// Whether the query terms will match full words and not parts of a word.
    public var wholeWord: Bool?

    /// Matches results exactly as stated in the query terms, taking into account stop words, order and spelling.
    public var exact: Bool?

    /// Language overriding the publication's language.
    public var language: Language?

    /// The search string is treated as a regular expression.
    /// The particular flavor of regex depends on the service.
    public var regularExpression: Bool?

    /// Map of custom options implemented by a Search Service which are not officially recognized by Readium.
    public var otherOptions: [String: String]

    /// Syntactic sugar to access the `otherOptions` values by subscripting `SearchOptions` directly.
    /// options["com.company.x"]
    public subscript(_ key: String) -> String? {
        get { otherOptions[key] }
        set { otherOptions[key] = newValue }
    }

    public init(
        caseSensitive: Bool? = nil,
        diacriticSensitive: Bool? = nil,
        wholeWord: Bool? = nil,
        exact: Bool? = nil,
        language: Language? = nil,
        regularExpression: Bool? = nil,
        otherOptions: [String: String] = [:]
    ) {
        self.caseSensitive = caseSensitive
        self.diacriticSensitive = diacriticSensitive
        self.wholeWord = wholeWord
        self.exact = exact
        self.language = language
        self.regularExpression = regularExpression
        self.otherOptions = otherOptions
    }
}

public typealias SearchResult<Success> = Result<Success, SearchError>

/// Represents an error which might occur during a search activity.
public enum SearchError: Error {
    /// The publication is not searchable.
    case publicationNotSearchable

    /// The provided search query cannot be handled by the service.
    case badQuery(Error)

    /// An error occurred while accessing one of the publication's resources.
    case reading(ReadError)
}

// MARK: Publication Helpers

public extension Publication {
    private var searchService: SearchService? { findService(SearchService.self) }

    /// Indicates whether the content of this publication can be searched.
    var isSearchable: Bool {
        searchService != nil
    }

    /// Default value for the search options of this publication.
    var searchOptions: SearchOptions {
        searchService?.options ?? SearchOptions()
    }

    /// Starts a new search through the publication content, with the given `query`.
    /// If an option is nil when calling search(), its value is assumed to be the default one for the search service.
    @discardableResult
    func search(query: String, options: SearchOptions? = nil) async -> SearchResult<SearchIterator> {
        guard let service = searchService else {
            return .failure(.publicationNotSearchable)
        }
        return await service.search(query: query, options: options)
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    mutating func setSearchServiceFactory(_ factory: SearchServiceFactory?) {
        if let factory = factory {
            set(SearchService.self, factory)
        } else {
            remove(SearchService.self)
        }
    }
}
