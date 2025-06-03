//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup

/// Extracts pure content from a marked-up (e.g. HTML) or binary (e.g. PDF) resource.
///
/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
public protocol _ResourceContentExtractor {
    /// Extracts the text content of the given `resource`.
    func extractText(of resource: Resource) async -> ReadResult<String>
}

/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
public protocol _ResourceContentExtractorFactory {
    /// Creates a `ResourceContentExtractor` instance for the given `resource`.
    /// Returns null if the resource format is not supported.
    func makeExtractor(for resource: Resource, mediaType: MediaType) -> _ResourceContentExtractor?
}

/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
public class _DefaultResourceContentExtractorFactory: _ResourceContentExtractorFactory {
    public init() {}

    public func makeExtractor(for resource: Resource, mediaType: MediaType) -> _ResourceContentExtractor? {
        if mediaType.isHTML {
            return _HTMLResourceContentExtractor()
        } else {
            return nil
        }
    }
}

/// `ResourceContentExtractor` implementation for HTML resources.
///
/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
class _HTMLResourceContentExtractor: _ResourceContentExtractor {
    private let xmlFactory = DefaultXMLDocumentFactory()

    func extractText(of resource: Resource) async -> ReadResult<String> {
        await resource.readAsString()
            .asyncFlatMap { content in
                do {
                    // First try to parse a valid XML document, then fallback on SwiftSoup, which is slower.
                    var text = await parse(xml: content)
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

    // Parse the HTML resource as a strict XML document.
    //
    // This is much more efficient than using SwiftSoup, but will fail when encountering
    // invalid HTML documents.
    private func parse(xml: String) async -> String? {
        guard let document = try? await xmlFactory.open(string: xml, namespaces: [.xhtml]) else {
            return nil
        }

        return document.first("/xhtml:html/xhtml:body")?.textContent
    }

    // Parse the HTML resource with SwiftSoup.
    //
    // This may be slow but will recover from broken HTML documents.
    private func parse(html: String) -> String? {
        try? SwiftSoup.parse(html).body()?.text()
    }
}
