//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias SearchServiceFactory = (PublicationServiceContext) -> _SearchService?

/// Provides a way to search terms in a publication.
///
/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
public protocol _SearchService: PublicationService {

    /// Default value for the search options of this service.
    ///
    /// If an option does not have a value, it is not supported by the service.
    var options: SearchOptions { get }

    /// Starts a new search through the publication content, with the given `query`.
    /// If an option is nil when calling search(), its value is assumed to be the default one.
    @discardableResult
    func search(query: String, options: SearchOptions?, completion: @escaping (SearchResult<SearchIterator>) -> Void) -> Cancellable
}

/// Iterates through search results.
public protocol SearchIterator {

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
    func next(completion: @escaping (SearchResult<_LocatorCollection?>) -> Void) -> Cancellable

    /// Closes any resources allocated for the search query, such as a cursor.
    /// To be called when the user dismisses the search.
    func close()
}

public extension SearchIterator {

    /// Iterates over all the search results, calling the given `block` for each page.
    @discardableResult
    func forEach(_ block: @escaping (_LocatorCollection) throws -> Void, completion: @escaping (SearchResult<Void>) -> Void) -> Cancellable {
        let mediator = MediatorCancellable()

        func next() {
            let cancellable = self.next { result in
                switch result {
                case .success(let locators):
                    if let locators = locators {
                        do {
                            try block(locators)
                            next()
                        } catch {
                            completion(.failure(.wrap(error)))
                        }
                    } else {
                        completion(.success(()))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            mediator.mediate(cancellable)
        }

        next()
        return mediator
    }

    func close() {}
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

    /// BCP 47 language code overriding the publication's language.
    public var language: String?

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
        language: String? = nil,
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
public enum SearchError: LocalizedError {

    /// The publication is not searchable.
    case publicationNotSearchable

    /// The provided search query cannot be handled by the service.
    case badQuery(LocalizedError)

    /// An error occurred while accessing one of the publication's resources.
    case resourceError(ResourceError)

    /// An error occurred while performing an HTTP request.
    case networkError(HTTPError)

    /// The search was cancelled by the caller.
    ///
    /// For example, when a network request is cancelled.
    case cancelled

    /// For any other custom service error.
    case other(Error)

    public static func wrap(_ error: Error) -> SearchError {
        switch error {
        case let error as SearchError:
            return error
        case let error as ResourceError:
            return .resourceError(error)
        case let error as HTTPError:
            return .networkError(error)
        default:
            return .other(error)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .publicationNotSearchable:
            return R2SharedLocalizedString("Publication.SearchError.publicationNotSearchable")
        case .badQuery(let error):
            return error.errorDescription
        case .resourceError(let error):
            return error.errorDescription
        case .networkError(let error):
            return error.errorDescription
        case .cancelled:
            return R2SharedLocalizedString("Publication.SearchError.cancelled")
        case .other:
            return R2SharedLocalizedString("Publication.SearchError.other")
        }
    }

}


// MARK: Publication Helpers

public extension Publication {

    private var searchService: _SearchService? { findService(_SearchService.self) }

    /// Indicates whether the content of this publication can be searched.
    ///
    /// **WARNING:** This API is experimental and may change or be removed in a future release without
    /// notice. Use with caution.
    var _isSearchable: Bool {
        searchService != nil
    }

    /// Default value for the search options of this publication.
    ///
    /// **WARNING:** This API is experimental and may change or be removed in a future release without
    /// notice. Use with caution.
    var _searchOptions: SearchOptions {
        searchService?.options ?? SearchOptions()
    }

    /// Starts a new search through the publication content, with the given `query`.
    /// If an option is nil when calling search(), its value is assumed to be the default one for the search service.
    ///
    /// **WARNING:** This API is experimental and may change or be removed in a future release without
    /// notice. Use with caution.
    @discardableResult
    func _search(query: String, options: SearchOptions? = nil, completion: @escaping (SearchResult<SearchIterator>) -> Void) -> Cancellable {
        guard let service = searchService else {
            let cancellable = CancellableObject()
            DispatchQueue.main.async(unlessCancelled: cancellable) {
                completion(.failure(.publicationNotSearchable))
            }
            return cancellable
        }

        return service.search(query: query, options: options, completion: completion)
    }

}


// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {

    mutating func setSearchServiceFactory(_ factory: SearchServiceFactory?) {
        if let factory = factory {
            set(_SearchService.self, factory)
        } else {
            remove(_SearchService.self)
        }
    }

}
