//
//  OPFMeta.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 04.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import Fuzi
import R2Shared


/// Package vocabularies used for `property`, `properties`, `scheme` and `rel`.
/// http://www.idpf.org/epub/301/spec/epub-publications.html#sec-metadata-assoc
enum OPFVocabulary: String {
    // Fallback prefixes for metadata's properties and links' rels.
    case defaultMetadata, defaultLinkRel
    // Reserved prefixes (https://idpf.github.io/epub-prefixes/packages/).
    case a11y, dcterms, epubsc, marc, media, onix, rendition, schema, xsd
    // Additional prefixes used in the streamer.
    case calibre
    
    var uri: String {
        switch self {
        case .defaultMetadata:
            return "http://idpf.org/epub/vocab/package/#"
        case .defaultLinkRel:
            return "http://idpf.org/epub/vocab/package/link/#"
        case .a11y:
            return "http://www.idpf.org/epub/vocab/package/a11y/#"
        case .dcterms:
            return "http://purl.org/dc/terms/"
        case .epubsc:
            return "http://idpf.org/epub/vocab/sc/#"
        case .marc:
            return "http://id.loc.gov/vocabulary/"
        case .media:
            return "http://www.idpf.org/epub/vocab/overlays/#"
        case .onix:
            return "http://www.editeur.org/ONIX/book/codelists/current.html#"
        case .rendition:
            return "http://www.idpf.org/vocab/rendition/#"
        case .schema:
            return "http://schema.org/"
        case .xsd:
            return "http://www.w3.org/2001/XMLSchema#"
        case .calibre:
            // https://github.com/kovidgoyal/calibre/blob/3f903cbdd165e0d1c5c25eecb6eef2a998342230/src/calibre/ebooks/metadata/opf3.py#L170
            return "https://calibre-ebook.com"
        }
    }
    
    /// Returns the property stripped of its prefix, and the associated vocabulary URI for the given
    /// metadata property.
    ///
    /// - Parameter prefixes: Custom prefixes declared in the package.
    static func parse(property: String, prefixes: [String: String] = [:]) -> (property: String, vocabularyURI: String) {
        let property = property.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let regex = try! NSRegularExpression(pattern: "^\\s*(\\S+?):\\s*(.+?)\\s*$")
        guard let match = regex.firstMatch(in: property, range: NSRange(property.startIndex..., in: property)),
            let prefixRange = Range(match.range(at: 1), in: property),
            let propertyRange = Range(match.range(at: 2), in: property) else
        {
            return (property, OPFVocabulary.defaultMetadata.uri)
        }
        
        let prefix = String(property[prefixRange])
        return (
            property: String(property[propertyRange]),
            vocabularyURI: resolveURI(ofPrefix: prefix, prefixes: prefixes)
        )
    }

    private static func resolveURI(ofPrefix prefix: String, prefixes: [String: String]) -> String {
        if let uri = prefixes[prefix] {
            switch uri {
                
            // The dc URI is expanded as dcterms
            // See https://www.dublincore.org/specifications/dublin-core/dcmi-terms/
            // > While these distinctions are significant for creators of RDF applications, most
            // > users can safely treat the fifteen parallel properties as equivalent. The most
            // > useful properties and classes of DCMI Metadata Terms have now been published as
            // > ISO 15836-2:2019 [ISO 15836-2:2019]. While the /elements/1.1/ namespace will be
            // > supported indefinitely, DCMI gently encourages use of the /terms/ namespace.
            case "http://purl.org/dc/elements/1.1/":
                return OPFVocabulary.dcterms.uri
                
            default:
                return uri
            }
        }
        
        let prefix = (prefix == "dc") ? "dcterms" : prefix
        return (OPFVocabulary(rawValue: prefix) ?? .defaultMetadata).uri
    }
    
    
    /// Parses the custom vocabulary prefixes declared in the given package document.
    /// > Reserved prefixes should not be overridden in the prefix attribute, but Reading Systems
    /// > must use such local overrides when encountered.
    /// http://www.idpf.org/epub/301/spec/epub-publications.html#sec-metadata-reserved-vocabs
    static func prefixes(in document: Fuzi.XMLDocument) -> [String: String] {
        document.definePrefix("opf", forNamespace: "http://www.idpf.org/2007/opf")
        guard let prefixAttribute = document.firstChild(xpath: "/opf:package")?.attr("prefix") else {
            return [:]
        }
        return try! NSRegularExpression(pattern: "(\\S+?):\\s*(\\S+)")
            .matches(in: prefixAttribute, range: NSRange(prefixAttribute.startIndex..., in: prefixAttribute))
            .reduce([:]) { prefixes, match in
                guard match.numberOfRanges == 3,
                    let prefixRange = Range(match.range(at: 1), in: prefixAttribute),
                    let uriRange = Range(match.range(at: 2), in: prefixAttribute) else
                {
                    return prefixes
                }
                let prefix = String(prefixAttribute[prefixRange])
                let uri = String(prefixAttribute[uriRange])
                var prefixes = prefixes
                prefixes[prefix] = uri
                return prefixes
        }
    }

}


/// Represents a `meta` tag in an OPF document.
struct OPFMeta {
    let property: String
    /// URI of the property's vocabulary.
    let vocabularyURI: String
    let content: String
    let id: String?
    /// ID of the metadata that is refined by this one, if any.
    let refines: String?
    let element: Fuzi.XMLElement
}


struct OPFMetaList {
    
    private let document: Fuzi.XMLDocument
    private let metas: [OPFMeta]
    
    init(document: Fuzi.XMLDocument) {
        self.document = document
        let prefixes = OPFVocabulary.prefixes(in: document)
        document.definePrefix("opf", forNamespace: "http://www.idpf.org/2007/opf")
        document.definePrefix("dc", forNamespace: "http://purl.org/dc/elements/1.1/")

        // Parses `<meta>` and `<dc:x>` tags in order of appearance.
        let root = "/opf:package/opf:metadata"
        self.metas = document.xpath("\(root)/opf:meta|\(root)/dc:*|\(root)/opf:dc-metadata/dc:*|\(root)/opf:x-metadata/opf:meta")
            .compactMap { meta in
                if meta.tag == "meta" {
                    // EPUB 3
                    if let property = meta.attr("property") {
                        let (property, vocabularyURI) = OPFVocabulary.parse(property: property, prefixes: prefixes)
                        var refinedID = meta.attr("refines")
                        refinedID?.removeFirst()  // Get rid of the # before the ID.
                        return OPFMeta(
                            property: property, vocabularyURI: vocabularyURI,
                            content: meta.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                            id: meta.attr("id"), refines: refinedID, element: meta
                        )
                    // EPUB 2
                    } else if let property = meta.attr("name") {
                        let (property, vocabularyURI) = OPFVocabulary.parse(property: property, prefixes: prefixes)
                        return OPFMeta(
                            property: property, vocabularyURI: vocabularyURI,
                            content: meta.attr("content")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                            id: nil, refines: nil, element: meta
                        )
                    } else {
                        return nil
                    }
                    
                // <dc:x>
                } else {
                    guard let property = meta.tag else {
                        return nil
                    }
                    return OPFMeta(
                        property: property,
                        vocabularyURI: OPFVocabulary.dcterms.uri,
                        content: meta.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                        id: meta.attr("id"),
                        refines: nil,
                        element: meta
                    )
                }
            }
    }
    
    subscript(_ property: String) -> [OPFMeta] {
        return self[property, in: .defaultMetadata]
    }

    subscript(_ property: String, refining id: String) -> [OPFMeta] {
        return self[property, in: .defaultMetadata, refining: id]
    }
    
    subscript(_ property: String, in vocabulary: OPFVocabulary) -> [OPFMeta] {
        return metas.filter { $0.property == property && $0.vocabularyURI == vocabulary.uri }
    }
    
    subscript(_ property: String, in vocabulary: OPFVocabulary, refining id: String) -> [OPFMeta] {
        return metas.filter { $0.property == property && $0.vocabularyURI == vocabulary.uri && $0.refines == id }
    }
    
    /// Returns the JSON representation of the unknown metadata
    /// (for RWPM's `Metadata.otherMetadata`)
    var otherMetadata: [String: Any] {
        var metadata: [String: NSMutableOrderedSet] = [:]

        for meta in metas {
            guard meta.refines == nil, !isRWPMProperty(meta) else {
                continue
            }
            let key = meta.vocabularyURI + meta.property
            let values = metadata[key] ?? NSMutableOrderedSet()
            values.add(value(for: meta))
            metadata[key] = values
        }
        
        return metadata.compactMapValues { values in
            switch values.count {
            case 0:
                return nil
            case 1:
                return values[0]
            default:
                return values.array
            }
        }
    }
    
    /// Returns the meta's content as value, or a special JSON object is the meta is refined, eg.:
    /// {
    ///   "@value": "Main value",
    ///   "http://my.url/#customPropertyUsedInRefine": "Refine value"
    /// }
    private func value(for meta: OPFMeta) -> Any {
        if let id = meta.id {
            let refines = metas.filter { $0.refines == id }
            if !refines.isEmpty {
                var value: [String: Any] = ["@value": meta.content]
                for refine in refines {
                    value[refine.vocabularyURI + refine.property] = refine.content
                }
                return value
            }
        }
        return meta.content
    }
    
    /// List of properties that should not be added to `otherMetadata` because they are already
    /// consumed by the RWPM model.
    private let rwpmProperties: [OPFVocabulary: [String]] = [
        .defaultMetadata: ["cover"],
        .dcterms: [
            "contributor", "creator", "date", "description", "identifier", "language", "modified",
            "publisher", "subject", "title"
        ],
        .media: ["duration"],
        .rendition: ["flow", "layout", "orientation", "spread"],
        .schema: ["numberOfPages"]
    ]
    
    /// Returns whether the given meta is a known RWPM property, and should therefore be ignored in
    /// `otherMetadata`.
    private func isRWPMProperty(_ meta: OPFMeta) -> Bool {
        let vocabularyProperties = (rwpmProperties.first { $0.key.uri == meta.vocabularyURI })?.value ?? []
        return vocabularyProperties.contains(meta.property)
    }

}
