//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Base implementation of `SearchService` iterating through the content of Publication's resources.
///
/// To stay media-type-agnostic, `StringSearchService` relies on `ResourceContentExtractor` implementations to retrieve
/// the pure text content from markups (e.g. HTML) or binary (e.g. PDF) resources.
///
/// The actual search is implemented by the provided `searchAlgorithm`.
///
/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
public class _StringSearchService: _SearchService {

    public static func makeFactory(
        snippetLength: Int = 200,
        searchAlgorithm: StringSearchAlgorithm = BasicStringSearchAlgorithm(),
        extractorFactory: _ResourceContentExtractorFactory = _DefaultResourceContentExtractorFactory()
    ) -> (PublicationServiceContext) -> _StringSearchService? {
        return { context in
            _StringSearchService(
                publication: context.publication,
                language: context.manifest.metadata.languages.first,
                snippetLength: snippetLength,
                searchAlgorithm: searchAlgorithm,
                extractorFactory: extractorFactory
            )
        }
    }

    public let options: SearchOptions

    private let publication: Weak<Publication>
    private let locale: Locale?
    private let snippetLength: Int
    private let searchAlgorithm: StringSearchAlgorithm
    private let extractorFactory: _ResourceContentExtractorFactory

    public init(publication: Weak<Publication>, language: String?, snippetLength: Int, searchAlgorithm: StringSearchAlgorithm, extractorFactory: _ResourceContentExtractorFactory) {
        self.publication = publication
        self.locale = language.map { Locale(identifier: $0) }
        self.snippetLength = snippetLength
        self.searchAlgorithm = searchAlgorithm
        self.extractorFactory = extractorFactory

        var options = searchAlgorithm.options
        options.language = locale?.languageCode ?? Locale.current.languageCode ?? "en"
        self.options = options
    }

    public func search(query: String, options: SearchOptions?, completion: @escaping (SearchResult<SearchIterator>) -> ()) -> Cancellable {
        let cancellable = CancellableObject()

        DispatchQueue.main.async(unlessCancelled: cancellable) {
            guard let publication = self.publication() else {
                completion(.failure(.cancelled))
                return
            }

            completion(.success(Iterator(
                publication: publication,
                locale: self.locale,
                snippetLength: self.snippetLength,
                searchAlgorithm: self.searchAlgorithm,
                extractorFactory: self.extractorFactory,
                query: query,
                options: options
            )))
        }

        return cancellable
    }

    private class Iterator: SearchIterator, Loggable {

        private(set) var resultCount: Int? = 0

        private let publication: Publication
        private let locale: Locale?
        private let snippetLength: Int
        private let searchAlgorithm: StringSearchAlgorithm
        private let extractorFactory: _ResourceContentExtractorFactory
        private let query: String
        private let options: SearchOptions

        fileprivate init(
            publication: Publication,
            locale: Locale?,
            snippetLength: Int,
            searchAlgorithm: StringSearchAlgorithm,
            extractorFactory: _ResourceContentExtractorFactory,
            query: String,
            options: SearchOptions?
        ) {
            self.publication = publication
            self.locale = locale
            self.snippetLength = snippetLength
            self.searchAlgorithm = searchAlgorithm
            self.extractorFactory = extractorFactory
            self.query = query
            self.options = options ?? SearchOptions()
        }

        /// Index of the last reading order resource searched in.
        private var index = -1

        func next(completion: @escaping (SearchResult<_LocatorCollection?>) -> ()) -> Cancellable {
            let cancellable = CancellableObject()
            DispatchQueue.global().async(unlessCancelled: cancellable) {
                self.findNext(cancellable) { result in
                    DispatchQueue.main.async(unlessCancelled: cancellable) {
                        completion(result)
                    }
                }
            }
            return cancellable
        }

        private func findNext(_ cancellable: CancellableObject, _ completion: @escaping (SearchResult<_LocatorCollection?>) -> ()) {
            guard index < publication.readingOrder.count - 1 else {
                completion(.success(nil))
                return
            }

            index += 1

            let link = publication.readingOrder[index]
            let resource = publication.get(link)

            do {
                guard let extractor = extractorFactory.makeExtractor(for: resource) else {
                    log(.warning, "Cannot extract text from resource: \(link.href)")
                    return findNext(cancellable, completion)
                }
                let text = try extractor.extractText(of: resource).get()

                let locators = findLocators(in: link, resourceIndex: index, text: text, cancellable: cancellable)
                // If no occurrences were found in the current resource, skip to the next one automatically.
                guard !locators.isEmpty else {
                    return findNext(cancellable, completion)
                }

                resultCount = (resultCount ?? 0) + locators.count
                completion(.success(_LocatorCollection(locators: locators)))

            } catch {
                completion(.failure(.wrap(error)))
            }
        }

        private func findLocators(in link: Link, resourceIndex: Int, text: String, cancellable: CancellableObject) -> [Locator] {
            guard !text.isEmpty else {
                return []
            }

            let currentLocale = options.language.map { Locale(identifier: $0) } ?? locale
            let title = publication.tableOfContents.titleMatchingHREF(link.href) ?? link.title
            let resourceLocator = Locator(link: link).copy(title: title)

            var locators: [Locator] = []

            for range in searchAlgorithm.findRanges(of: query, options: options, in: text, locale: currentLocale, cancellable: cancellable) {
                guard !cancellable.isCancelled else {
                    return locators
                }

                locators.append(makeLocator(resourceIndex: index, resourceLocator: resourceLocator, text: text, range: range))
            }

            return locators
        }

        private func makeLocator(resourceIndex: Int, resourceLocator: Locator, text: String, range: Range<String.Index>) -> Locator {
            let progression = max(0.0, min(1.0, Double(range.lowerBound.utf16Offset(in: text)) / Double(text.endIndex.utf16Offset(in: text))))

            var totalProgression: Double? = nil
            let positions = publication.positionsByReadingOrder
            if let resourceStartTotalProg = positions.getOrNil(resourceIndex)?.first?.locations.totalProgression {
                let resourceEndTotalProg = positions.getOrNil(resourceIndex + 1)?.first?.locations.totalProgression ?? 1.0
                totalProgression = resourceStartTotalProg + progression * (resourceEndTotalProg - resourceStartTotalProg)
            }

            return resourceLocator.copy(
                locations: {
                    $0.progression = progression
                    $0.totalProgression = totalProgression
                },
                text: {
                    $0 = self.makeSnippet(text: text, range: range)
                }
            )
        }

        /// Extracts a snippet from the given `text` at the provided highlight `range`.
        /// Makes sure that words are not cut off at the boundaries.
        private func makeSnippet(text: String, range: Range<String.Index>) -> Locator.Text {
            var before = ""
            var count = snippetLength
            for char in text[...range.lowerBound].reversed().dropFirst() {
                guard count >= 0 || !char.isWhitespace else {
                    break
                }
                count -= 1
                before.insert(char, at: before.startIndex)
            }

            var after = ""
            count = snippetLength
            for char in text[range.upperBound...] {
                guard count >= 0 || !char.isWhitespace else {
                    break
                }
                count -= 1
                after.append(char)
            }

            return Locator.Text(
                after: after,
                before: before,
                highlight: String(text[range])
            )
        }
    }
}

/// Implements the actual search algorithm in sanitized text content.
public protocol StringSearchAlgorithm {

    /// Default value for the search options available with this algorithm.
    ///
    /// If an option does not have a value, it is not supported by the algorithm.
    var options: SearchOptions { get }

    /// Finds all the ranges of occurrences of the given `query` in the `text`.
    ///
    /// Implementers should check `cancellable.isCancelled` frequently to abort the search if needed.
    func findRanges(of query: String, options: SearchOptions, in text: String, locale: Locale?, cancellable: CancellableObject) -> [Range<String.Index>]
}

/// A basic `StringSearchAlgorithm` using the native `String.range(of:)` APIs.
public class BasicStringSearchAlgorithm: StringSearchAlgorithm {

    public let options: SearchOptions = SearchOptions(
        caseSensitive: false,
        diacriticSensitive: false,
        exact: false,
        regularExpression: false
    )

    public init() {}

    public func findRanges(of query: String, options: SearchOptions, in text: String, locale: Locale?, cancellable: CancellableObject) -> [Range<Swift.String.Index>] {
        var compareOptions: NSString.CompareOptions = []
        if options.regularExpression ?? false {
            compareOptions.insert(.regularExpression)
        } else if (options.exact ?? false) {
            compareOptions.insert(.literal)
        } else {
            if !(options.caseSensitive ?? false) {
                compareOptions.insert(.caseInsensitive)
            }
            if !(options.diacriticSensitive ?? false) {
                compareOptions.insert(.diacriticInsensitive)
            }
        }

        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while
            !cancellable.isCancelled,
            index < text.endIndex,
            let range = text.range(of: query, options: compareOptions, range: index..<text.endIndex, locale: locale),
            !range.isEmpty
        {
            ranges.append(range)
            index = text.index(range.lowerBound, offsetBy: 1)
        }

        return ranges
    }
}

fileprivate extension Array where Element == Link {
    func titleMatchingHREF(_ href: String) -> String? {
        for link in self {
            if let title = link.titleMatchingHREF(href) {
                return title
            }
        }
        return nil
    }
}

fileprivate extension Link {
    func titleMatchingHREF(_ targetHREF: String) -> String? {
        if (href.substringBeforeLast("#") == targetHREF) {
            return title
        }
        return children.titleMatchingHREF(targetHREF)
    }
}