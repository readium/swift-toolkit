//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs an HTML or XHTML document.
public struct HTMLFormatSniffer: FormatSniffer, Sendable {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("htm", "html") ||
            hints.hasMediaType("text/html")
        {
            return html
        }

        if
            hints.hasFileExtension("xht", "xhtml") ||
            hints.hasMediaType("application/xhtml+xml")
        {
            return xhtml
        }

        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async throws(ReadError) -> Format? {
        guard !format.hasSpecification || format.conformsTo(.xml) else {
            return nil
        }

        let document = try await blob.readAsXML()
        if let format = sniffDocument(document) {
            return format
        } else if let format = try await sniffString(blob) {
            return format
        } else {
            return nil
        }
    }

    private func sniffDocument(_ document: XMLDocument?) -> Format? {
        guard
            let element = document?.documentElement,
            element.localName.lowercased() == "html"
        else {
            return nil
        }

        if element.first("xhtml:body|xhtml2:body", with: [.xhtml, .xhtml2]) != nil {
            return xhtml
        } else {
            return html
        }
    }

    private func sniffString(_ blob: FormatSnifferBlob) async throws(ReadError) -> Format? {
        guard
            let string = try await blob.readAsString(),
            string.trimmingCharacters(in: .whitespacesAndNewlines).prefix(15).lowercased() == "<!doctype html>"
        else {
            return nil
        }
        return html
    }

    private let html = Format(
        specifications: .xml, .html,
        mediaType: .html,
        fileExtension: "html"
    )

    private let xhtml = Format(
        specifications: .xml, .html,
        mediaType: .xhtml,
        fileExtension: "xhtml"
    )
}
