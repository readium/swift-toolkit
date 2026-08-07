//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias ContentServiceFactory = (PublicationServiceContext) -> ContentService?

/// Provides a way to extract the raw `Content` of a `Publication`.
public protocol ContentService: PublicationService {
    /// Creates a `Content` starting from the given `start` location.
    ///
    /// The implementation must be fast and non-blocking. Do the actual
    /// extraction inside the `Content` implementation.
    func content(from start: Locator?) -> Content?
}

/// Default implementation of `ContentService`, delegating the content parsing
/// to `ResourceContentIteratorFactory`.
public final class DefaultContentService: ContentService, Sendable {
    private let publication: Weak<Publication>
    private let resourceContentIteratorFactories: [ResourceContentIteratorFactory]
    private let pageArtifactDetectors: [PageArtifactDetector]
    private let hardBreakDetectors: [HardBreakDetector]

    /// - Parameters:
    ///   - resourceContentIteratorFactories: Factories used to create the
    ///     iterator for each resource, tried in order until there's a match.
    ///   - pageArtifactDetectors: Detectors used to identify page-boundary
    ///     noise (page numbers, running headers) when re-segmenting
    ///     fixed-layout content into sentences.
    ///   - hardBreakDetectors: Detectors used to identify standalone display
    ///     text (part headings, title pages) which must never be merged into
    ///     a surrounding sentence.
    public init(
        publication: Weak<Publication>,
        resourceContentIteratorFactories: [ResourceContentIteratorFactory],
        pageArtifactDetectors: [PageArtifactDetector] = [PageNumberArtifactDetector(), RunningHeaderArtifactDetector()],
        hardBreakDetectors: [HardBreakDetector] = [SpacedCapsHardBreakDetector(), HeadingHardBreakDetector(), StandalonePageHardBreakDetector()]
    ) {
        self.publication = publication
        self.resourceContentIteratorFactories = resourceContentIteratorFactories
        self.pageArtifactDetectors = pageArtifactDetectors
        self.hardBreakDetectors = hardBreakDetectors
    }

    public static func makeFactory(
        resourceContentIteratorFactories: [ResourceContentIteratorFactory],
        pageArtifactDetectors: [PageArtifactDetector] = [PageNumberArtifactDetector(), RunningHeaderArtifactDetector()],
        hardBreakDetectors: [HardBreakDetector] = [SpacedCapsHardBreakDetector(), HeadingHardBreakDetector(), StandalonePageHardBreakDetector()]
    ) -> (PublicationServiceContext) -> DefaultContentService? {
        { context in
            DefaultContentService(
                publication: context.publication,
                resourceContentIteratorFactories: resourceContentIteratorFactories,
                pageArtifactDetectors: pageArtifactDetectors,
                hardBreakDetectors: hardBreakDetectors
            )
        }
    }

    public func content(from start: Locator?) -> Content? {
        guard let pub = publication() else {
            return nil
        }
        return DefaultContent(
            publication: pub,
            start: start,
            resourceContentIteratorFactories: resourceContentIteratorFactories,
            pageArtifactDetectors: pageArtifactDetectors,
            hardBreakDetectors: hardBreakDetectors
        )
    }

    private final class DefaultContent: Content {
        let publication: Publication
        let start: Locator?
        let resourceContentIteratorFactories: [ResourceContentIteratorFactory]
        let pageArtifactDetectors: [PageArtifactDetector]
        let hardBreakDetectors: [HardBreakDetector]

        init(
            publication: Publication,
            start: Locator?,
            resourceContentIteratorFactories: [ResourceContentIteratorFactory],
            pageArtifactDetectors: [PageArtifactDetector],
            hardBreakDetectors: [HardBreakDetector]
        ) {
            self.publication = publication
            self.start = start
            self.resourceContentIteratorFactories = resourceContentIteratorFactories
            self.pageArtifactDetectors = pageArtifactDetectors
            self.hardBreakDetectors = hardBreakDetectors
        }

        func iterator() -> ContentIterator {
            let iterator = PublicationContentIterator(
                publication: publication,
                start: start,
                resourceContentIteratorFactories: resourceContentIteratorFactories
            )

            // Fixed-layout content is paginated by construction, cutting
            // sentences between printed lines, block elements and pages;
            // re-segment it so that each element holds one full sentence.
            //
            // Known limitation: this checks the publication-wide layout, so
            // per-spine-item `rendition:layout` overrides in mixed EPUBs are
            // ignored.
            guard publication.metadata.layout == .fixed || publication.conforms(to: .pdf) else {
                return iterator
            }

            return SentenceContentIterator(
                iterator: iterator,
                language: publication.metadata.language,
                artifactDetectors: pageArtifactDetectors,
                hardBreakDetectors: hardBreakDetectors
            )
        }
    }
}

// MARK: Publication Helpers

public extension Publication {
    /// Creates a `Content` starting from the given `start` location, or the
    /// beginning of the publication when missing.
    func content(from start: Locator? = nil) -> Content? {
        findService(ContentService.self)?.content(from: start)
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    mutating func setContentServiceFactory(_ factory: ContentServiceFactory?) {
        if let factory = factory {
            set(ContentService.self, factory)
        } else {
            remove(ContentService.self)
        }
    }
}
