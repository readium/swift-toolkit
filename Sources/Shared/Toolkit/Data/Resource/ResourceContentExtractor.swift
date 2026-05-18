//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup

/// Extracts pure content from a marked-up (e.g. HTML) or binary (e.g. PDF) resource.
public protocol ResourceContentExtractor {
    /// Extracts the text content of the given `resource`.
    func extractText(of resource: Resource) async -> ReadResult<String>
}

@available(*, unavailable, renamed: "ResourceContentExtractor")
public typealias _ResourceContentExtractor = ResourceContentExtractor

/// Creates a `ResourceContentExtractor` for a given resource and media type.
public protocol ResourceContentExtractorFactory {
    /// Creates a `ResourceContentExtractor` instance for the given `resource`.
    /// Returns nil if the resource format is not supported.
    func makeExtractor(for resource: Resource, mediaType: MediaType) -> ResourceContentExtractor?
}

@available(*, unavailable, renamed: "ResourceContentExtractorFactory")
public typealias _ResourceContentExtractorFactory = ResourceContentExtractorFactory

/// Default `ResourceContentExtractorFactory` supporting HTML resources.
public class DefaultResourceContentExtractorFactory: ResourceContentExtractorFactory {
    public init() {}

    public func makeExtractor(for resource: Resource, mediaType: MediaType) -> ResourceContentExtractor? {
        if mediaType.isHTML {
            return HTMLResourceContentExtractor()
        } else {
            return nil
        }
    }
}

@available(*, unavailable, renamed: "DefaultResourceContentExtractorFactory")
public typealias _DefaultResourceContentExtractorFactory = DefaultResourceContentExtractorFactory

/// `ResourceContentExtractor` implementation for HTML resources.
class HTMLResourceContentExtractor: ResourceContentExtractor {
    private let xmlFactory = DefaultXMLDocumentFactory()

    func extractText(of resource: Resource) async -> ReadResult<String> {
        await resource.read()
            .asString()
            .asyncFlatMap { content in
                do {
                    // First try to parse a valid XML document, then fallback on SwiftSoup, which is slower.
                    var text = parse(xml: content)
                        ?? parse(html: content)
                        ?? ""

                    // Transform HTML entities into their actual characters.
                    text = try Entities.unescape(text)

                    return .success(text)

                } catch {
                    return .failure(.decoding(error))
                }
            }
    }

    /// Parse the HTML resource as a strict XML document.
    ///
    /// This is much more efficient than using SwiftSoup, but will fail when encountering
    /// invalid HTML documents.
    private func parse(xml: String) -> String? {
        guard let document = try? xmlFactory.open(string: xml, namespaces: [.xhtml]) else {
            return nil
        }

        return document.first("/xhtml:html/xhtml:body")?.textContent
    }

    /// Parse the HTML resource with SwiftSoup.
    ///
    /// This may be slow but will recover from broken HTML documents.
    private func parse(html: String) -> String? {
        try? SwiftSoup.parse(html).body()?.text()
    }
}
