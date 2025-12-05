//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs OPDS documents.
public class OPDSFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if hints.hasMediaType("application/atom+xml;type=entry;profile=opds-catalog") {
            return opds1Entry
        }
        if hints.hasMediaType("application/atom+xml;profile=opds-catalog") {
            return opds1Catalog
        }

        if hints.hasMediaType("application/opds+json") {
            return opds2Catalog
        }
        if hints.hasMediaType("application/opds-publication+json") {
            return opds2Publication
        }

        if hints.hasMediaType("application/opds-authentication+json", "application/vnd.opds.authentication.v1.0+json") {
            return opdsAuthentication
        }
        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        if format.conformsTo(.xml) {
            return await blob.readAsXML()
                .map {
                    guard let document = $0 else {
                        return nil
                    }
                    let namespaces = [XMLNamespace.atom]
                    if document.first("/atom:feed", with: namespaces) != nil {
                        return opds1Catalog
                    } else if document.first("/atom:entry", with: namespaces) != nil {
                        return opds1Entry
                    } else {
                        return nil
                    }
                }

        } else if format.conformsTo(.json) {
            return await blob.readAsJSON()
                .map { json in
                    guard let json = json as? [String: Any] else {
                        return nil
                    }

                    if let rwpm = try? Manifest(json: json) {
                        if rwpm.linkWithRel(.`self`)?.mediaType?.matches(.opds2) == true {
                            return opds2Catalog
                        }
                        if !rwpm.linksMatching({ $0.rels.contains { $0.hasPrefix("http://opds-spec.org/acquisition") } }).isEmpty {
                            return opds2Publication
                        }
                        return nil
                    }

                    if Set(json.keys).isSuperset(of: ["id", "title", "authentication"]) {
                        return opdsAuthentication
                    }

                    return nil
                }

        } else {
            return .success(nil)
        }
    }

    public let opds1Catalog = Format(specifications: .xml, .opds1Catalog, mediaType: .opds1, fileExtension: "xml")
    public let opds1Entry = Format(specifications: .xml, .opds1Entry, mediaType: .opds1Entry, fileExtension: "xml")
    public let opds2Catalog = Format(specifications: .json, .opds2Catalog, mediaType: .opds2, fileExtension: "json")
    public let opds2Publication = Format(specifications: .json, .opds2Publication, mediaType: .opds2Publication, fileExtension: "json")
    public let opdsAuthentication = Format(specifications: .json, .opdsAuthentication, mediaType: .opdsAuthentication, fileExtension: "json")
}
