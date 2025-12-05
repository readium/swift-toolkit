//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs an EPUB publication.
///
/// Reference: https://www.w3.org/publishing/epub3/epub-ocf.html#sec-zip-container-mime
public struct EPUBFormatSniffer: FormatSniffer {
    private let xmlDocumentFactory: XMLDocumentFactory

    public init(xmlDocumentFactory: XMLDocumentFactory) {
        self.xmlDocumentFactory = xmlDocumentFactory
    }

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("epub") ||
            hints.hasMediaType("application/epub+zip")
        {
            return Format(
                specifications: .zip, .epub,
                mediaType: .epub,
                fileExtension: "epub"
            )
        }

        return nil
    }

    public func sniffContainer<C>(_ container: C, refining format: Format) async -> ReadResult<Format?> where C: Container {
        guard let resource = container[AnyURL(path: "mimetype")!] else {
            return .success(nil)
        }

        return await resource.readAsString()
            .asyncFlatMap { mimetype in
                if MediaType.epub.matches(MediaType(mimetype.trimmingCharacters(in: .whitespacesAndNewlines))) {
                    var format = format
                    format.addSpecifications(.epub)
                    if format.conformsTo(.zip) {
                        format.mediaType = .epub
                        format.fileExtension = "epub"
                    }

                    return await sniffDRM(in: container, format: format)
                } else {
                    return .success(nil)
                }
            }
    }

    private func sniffDRM(in container: Container, format: Format) async -> ReadResult<Format?> {
        var format = format

        if container.entries.contains(AnyURL(path: "META-INF/license.lcpl")!) {
            format.addSpecifications(.lcp)
            return .success(format)
        }

        guard let resource = container[AnyURL(path: "META-INF/encryption.xml")!] else {
            return .success(format)
        }

        return await resource.read()
            .asyncMap { try? await xmlDocumentFactory.open(data: $0, namespaces: []) }
            .map { document in
                guard let document = document else {
                    return format
                }

                let namespaces: [XMLNamespace] = [.enc, .sig, .adept]

                if
                    document
                    .all("enc:EncryptedData/sig:KeyInfo/sig:RetrievalMethod", with: namespaces)
                    .contains(where: { $0.attribute(named: "URI") == "license.lcpl#/encryption/content_key" })
                {
                    format.addSpecifications(.lcp)
                }

                if document.first("enc:EncryptedData/sig:KeyInfo/adept:resource") != nil {
                    format.addSpecifications(.adept)
                }

                return format
            }
    }
}
