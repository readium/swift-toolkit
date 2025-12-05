//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Base implementation of `SearchService` iterating through the content of
/// Publication's resources.
///
/// To stay media-type-agnostic, `StringSearchService` relies on
/// `ResourceContentExtractor` implementations to retrieve the pure text
/// content from markups (e.g. HTML) or binary (e.g. PDF) resources.
///
/// The actual search is implemented by the provided `searchAlgorithm`.
public class StringSearchService: SearchService {
    public static func makeFactory(
        snippetLength: Int = 200,
        searchAlgorithm: StringSearchAlgorithm = BasicStringSearchAlgorithm(),
        extractorFactory: _ResourceContentExtractorFactory = _DefaultResourceContentExtractorFactory()
    ) -> (PublicationServiceContext) -> StringSearchService? {
        { context in
            StringSearchService(
                publication: context.publication,
                language: context.manifest.metadata.language,
                snippetLength: snippetLength,
                searchAlgorithm: searchAlgorithm,
                extractorFactory: extractorFactory
            )
        }
    }

    public let options: SearchOptions

    private let publication: Weak<Publication>
    private let language: Language?
    private let snippetLength: Int
    private let searchAlgorithm: StringSearchAlgorithm
    private let extractorFactory: _ResourceContentExtractorFactory

    public init(publication: Weak<Publication>, language: Language?, snippetLength: Int, searchAlgorithm: StringSearchAlgorithm, extractorFactory: _ResourceContentExtractorFactory) {
        self.publication = publication
        self.language = language
        self.snippetLength = snippetLength
        self.searchAlgorithm = searchAlgorithm
        self.extractorFactory = extractorFactory

        var options = searchAlgorithm.options
        options.language = language ?? Language.current
        self.options = options
    }

    public func search(query: String, options: SearchOptions?) async -> SearchResult<any SearchIterator> {
        guard let publication = publication() else {
            return .failure(.publicationNotSearchable)
        }

        return .success(Iterator(
            publication: publication,
            language: language,
            snippetLength: snippetLength,
            searchAlgorithm: searchAlgorithm,
            extractorFactory: extractorFactory,
            query: query,
            options: options
        ))
    }

    private class Iterator: SearchIterator, Loggable {
        private(set) var resultCount: Int? = 0

        private let publication: Publication
        private let language: Language?
        private let snippetLength: Int
        private let searchAlgorithm: StringSearchAlgorithm
        private let extractorFactory: _ResourceContentExtractorFactory
        private let query: String
        private let options: SearchOptions

        fileprivate init(
            publication: Publication,
            language: Language?,
            snippetLength: Int,
            searchAlgorithm: StringSearchAlgorithm,
            extractorFactory: _ResourceContentExtractorFactory,
            query: String,
            options: SearchOptions?
        ) {
            self.publication = publication
            self.language = language
            self.snippetLength = snippetLength
            self.searchAlgorithm = searchAlgorithm
            self.extractorFactory = extractorFactory
            self.query = query
            self.options = options ?? SearchOptions()
        }

        /// Index of the last reading order resource searched in.
        private var index = -1

        func next() async -> SearchResult<LocatorCollection?> {
            while index < publication.readingOrder.count - 1 {
                index += 1

                let link = publication.readingOrder[index]

                guard
                    let resource = publication.get(link),
                    let mediaType = link.mediaType,
                    let extractor = extractorFactory.makeExtractor(for: resource, mediaType: mediaType)
                else {
                    log(.warning, "Cannot extract text from resource: \(link.href)")
                    continue
                }

                switch await extractor.extractText(of: resource) {
                case let .success(text):
                    let locators = await findLocators(in: link, resourceIndex: index, text: text)
                    // If no occurrences were found in the current resource, skip to the next one automatically.
                    guard !locators.isEmpty else {
                        continue
                    }

                    resultCount = (resultCount ?? 0) + locators.count
                    return .success(LocatorCollection(locators: locators))

                case let .failure(error):
                    return .failure(.reading(error))
                }
            }

            return .success(nil)
        }

        private func findLocators(in link: Link, resourceIndex: Int, text: String) async -> [Locator] {
            guard
                !text.isEmpty,
                var resourceLocator = await publication.locate(link)
            else {
                return []
            }

            let title = await publication.tableOfContents().getOrNil()?.titleMatchingHREF(link.href)
            resourceLocator = resourceLocator.copy(
                title: Optional(title ?? link.title)
            )

            var locators: [Locator] = []

            let currentLanguage = options.language ?? language

            for range in await searchAlgorithm.findRanges(of: query, options: options, in: text, language: currentLanguage) {
                guard !Task.isCancelled else {
                    return locators
                }

                await locators.append(makeLocator(resourceIndex: index, resourceLocator: resourceLocator, text: text, range: range))
            }

            return locators
        }

        private func makeLocator(resourceIndex: Int, resourceLocator: Locator, text: String, range: Range<String.Index>) async -> Locator {
            let progression = max(0.0, min(1.0, Double(range.lowerBound.utf16Offset(in: text)) / Double(text.endIndex.utf16Offset(in: text))))

            var totalProgression: Double? = nil
            let positions = await publication.positionsByReadingOrder().getOrNil() ?? []
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
    func findRanges(
        of query: String,
        options: SearchOptions,
        in text: String,
        language: Language?
    ) async -> [Range<String.Index>]
}

/// A basic `StringSearchAlgorithm` using the native `String.range(of:)` APIs.
public class BasicStringSearchAlgorithm: StringSearchAlgorithm {
    public let options: SearchOptions = .init(
        caseSensitive: false,
        diacriticSensitive: false,
        exact: false,
        regularExpression: false
    )

    public init() {}

    public func findRanges(
        of query: String,
        options: SearchOptions,
        in text: String,
        language: Language?
    ) async -> [Range<String.Index>] {
        var compareOptions: NSString.CompareOptions = []
        if options.regularExpression ?? false {
            compareOptions.insert(.regularExpression)
        } else if options.exact ?? false {
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
            !Task.isCancelled,
            index < text.endIndex,
            let range = text.range(of: query, options: compareOptions, range: index ..< text.endIndex, locale: language?.locale),
            !range.isEmpty
        {
            ranges.append(range)
            index = text.index(range.lowerBound, offsetBy: 1)
        }

        return ranges
    }
}

private extension Array where Element == Link {
    func titleMatchingHREF(_ href: String) -> String? {
        for link in self {
            if let title = link.titleMatchingHREF(href) {
                return title
            }
        }
        return nil
    }
}

private extension Link {
    func titleMatchingHREF(_ targetHREF: String) -> String? {
        if href.substringBeforeLast("#") == targetHREF {
            return title
        }
        return children.titleMatchingHREF(targetHREF)
    }
}
