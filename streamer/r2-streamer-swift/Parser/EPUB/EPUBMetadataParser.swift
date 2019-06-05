//
//  EPUBMetadataParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri, Mickaël Menu on 3/17/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import Fuzi


/// Reference: https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md
final class EPUBMetadataParser: Loggable {
    
    private let document: XMLDocument
    private let displayOptions: XMLDocument?
    private let metas: OPFMetaList

    init(document: XMLDocument, displayOptions: XMLDocument?, metas: OPFMetaList) {
        self.document = document
        self.displayOptions = displayOptions
        self.metas = metas
        
        document.definePrefix("opf", forNamespace: "http://www.idpf.org/2007/opf")
        document.definePrefix("dc", forNamespace: "http://purl.org/dc/elements/1.1/")
        document.definePrefix("dcterms", forNamespace: "http://purl.org/dc/terms/")
        document.definePrefix("rendition", forNamespace: "http://www.idpf.org/2013/rendition")
    }
    
    private lazy var metadataElement: XMLElement? = {
        return document.firstChild(xpath: "/opf:package/opf:metadata")
    }()

    /// Parses the Metadata in the XML <metadata> element.
    func parse() throws -> Metadata {
        guard let title = mainTitle else {
            throw OPFParserError.missingPublicationTitle
        }
        
        var metadata = Metadata(
            identifier: uniqueIdentifier,
            title: title,
            subtitle: subtitle,
            modified: modifiedDate,
            published: publishedDate,
            languages: languages,
            sortAs: sortAs,
            subjects: subjects,
            readingProgression: readingProgression,
            description: description,
            otherMetadata: metas.otherMetadata
        )
        parseContributors(to: &metadata)
        metadata.rendition = rendition

        return metadata
    }
    
    private lazy var languages: [String] = {
        return metadataElement?.xpath("dc:language").map { $0.stringValue } ?? []
    }()
    
    private lazy var packageLanguage: String? = {
        return document.firstChild(xpath: "/opf:package")?.attr("lang")
    }()

    /// Determines the BCP-47 language tag for the given element, using:
    ///   1. its xml:lang attribute
    ///   2. the package's xml:lang attribute
    ///   3. the primary language for the publication
    private func language(for element: XMLElement) -> String? {
        return element.attr("lang") ?? packageLanguage ?? languages.first
    }
    
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#title
    private lazy var sortAs: String? = {
        // EPUB 3
        if let id = mainTitleElement?.attr("id"), let sortAsElement = metas["file-as", refining: id].first {
            return sortAsElement.content
        // EPUB 2
        } else {
            return metas["title_sort", in: .calibre].first?.content
        }
    }()
    
    private lazy var description: String? = {
        return metadataElement?.xpath("dc:description").first?.stringValue
    }()
    
    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    private lazy var rendition: EPUBRendition = {
        func renditionMetadata(_ property: String) -> String {
            return metas[property, in: .rendition].last?.content ?? ""
        }

        func displayOption(_ name: String) -> String? {
            // https://readium.org/architecture/streamer/parser/metadata#epub-2x-10
            guard let platform = displayOptions?.firstChild(xpath: "platform[@name='*']")
                ?? displayOptions?.firstChild(xpath: "platform[@name='ipad']")
                ?? displayOptions?.firstChild(xpath: "platform[@name='iphone']")
                ?? displayOptions?.firstChild(xpath: "platform") else
            {
                return nil
            }
            return platform.firstChild(xpath: "option[@name='\(name)']")?.stringValue
        }

        return EPUBRendition(
            layout: .init(
                epub: renditionMetadata("layout"),
                fallback: (displayOption("fixed-layout") == "true") ? .fixed : nil
            ),
            orientation: .init(
                epub: renditionMetadata("orientation"),
                fallback: {
                    let orientationLock = displayOption("orientation-lock") ?? ""
                    switch orientationLock {
                    case "none":
                        return .auto
                    case "landscape-only":
                        return .landscape
                    case "portrait-only":
                        return .portrait
                    default:
                        return nil
                    }
                }()
            ),
            overflow: .init(epub: renditionMetadata("flow")),
            spread: .init(epub: renditionMetadata("spread"))
        )
    }()

    /// Finds all the `<dc:title> element matching the given `title-type`.
    /// The elements are then sorted by the `display-seq` refines, when available.
    private func titleElements(ofType titleType: EPUBTitleType) -> [XMLElement] {
        // Finds the XML element corresponding to the specific title type
        // `<meta refines="#.." property="title-type" id="title-type">titleType</meta>`
        return metas["title-type"]
            .compactMap { meta in
                guard meta.content == titleType.rawValue, let id = meta.refines else {
                    return nil
                }
                return metadataElement?.firstChild(xpath: "dc:title[@id='\(id)']")
            }
            // Sort using `display-seq` refines
            .sorted { title1, title2 in
                let order1 = title1.attr("id").flatMap { displaySeqs[$0] } ?? ""
                let order2 = title2.attr("id").flatMap { displaySeqs[$0] } ?? ""
                return order1 < order2
            }
    }
    
    /// Maps between an element ID and its `display-seq` refine, if there's any.
    /// eg. <meta refines="#creator01" property="display-seq">1</meta>
    private lazy var displaySeqs: [String: String] = {
        return metas["display-seq"]
            .reduce([:]) { displaySeqs, meta in
                var displaySeqs = displaySeqs
                if let id = meta.refines {
                    displaySeqs[id] = meta.content
                }
                return displaySeqs
            }
    }()
    
    private lazy var mainTitleElement: XMLElement? = {
        return titleElements(ofType: .main).first
            ?? metadataElement?.firstChild(xpath: "dc:title")
    }()

    private lazy var mainTitle: LocalizedString? = {
        return localizedString(for: mainTitleElement)
    }()
    
    private lazy var subtitle: LocalizedString? = {
        return localizedString(for: titleElements(ofType: .subtitle).first)
    }()

    /// Parse and return the Epub unique identifier.
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#identifier
    private lazy var uniqueIdentifier: String? = metadataElement?
        .firstChild(xpath:"dc:identifier[@id=/opf:package/@unique-identifier]")?
        .stringValue

    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#publication-date
    private lazy var publishedDate = metadataElement?
        .firstChild(xpath: "dc:date[not(@opf:event) or @opf:event='publication']")?
        .stringValue.dateFromISO8601

    /// Parse the modifiedDate (date of last modification of the EPUB).
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#modification-date
    private lazy var modifiedDate: Date? = {
        let epub3Date = {
            self.metas["modified", in: .dcterms]
                .compactMap { $0.content.dateFromISO8601 }
                .first
        }
        let epub2Date = {
            self.metadataElement?.firstChild(xpath: "dc:date[@opf:event='modification']")?
                .stringValue.dateFromISO8601
        }
        return epub3Date() ?? epub2Date()
    }()

    /// Parse the <dc:subject> XML element from the metadata
    private lazy var subjects: [Subject] = {
        guard let metadataElement = metadataElement else {
            return []
        }
        return metadataElement.xpath("dc:subject")
            .compactMap { element in
                let name = element.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    log(.warning, "Invalid Epub, no value for <dc:subject>")
                    return nil
                }
                return Subject(
                    name: name,
                    scheme: element.attr("authority"),
                    code: element.attr("term")
                )
            }
    }()

    /// Parse all the Contributors objects of the model (`creator`, `contributor`,
    /// `publisher`) and add them to the metadata.
    ///
    /// - Parameters:
    ///   - metadata: The Metadata object to fill (inout).
    private func parseContributors(to metadata: inout Metadata) {
        // Parse XML elements and fill the metadata object.
        let contributors = findContributorMetaElements() + findContributorElements()
        for contributor in contributors {
            parseContributor(from: contributor, to: &metadata)
        }
    }

    /// [EPUB 2.0 & 3.1+]
    /// Return the XML elements about the contributors.
    /// E.g.: `<dc:publisher "property"=".." >value<\>`.
    ///
    /// - Parameter metadata: The XML metadata element.
    /// - Returns: The array of XML element representing the contributors.
    private func findContributorElements() -> [XMLElement] {
        return metadataElement?.xpath("dc:creator|dc:publisher|dc:contributor").map { $0 } ?? []
    }

    /// [EPUB 3.0]
    /// Return the XML elements about the contributors.
    /// E.g.: `<meta property="dcterms:publisher/creator/contributor"`.
    ///
    /// - Returns: The array of XML element representing the <meta> contributors.
    private func findContributorMetaElements() -> [XMLElement] {
        let contributors = metas["creator", in: .dcterms]
            + metas["publisher", in: .dcterms]
            + metas["contributor", in: .dcterms]
        return contributors.map { $0.element }
    }

    /// Parse a `creator`, `contributor`, `publisher` element from the OPF XML
    /// document, then builds and adds a Contributor to the metadata, to an
    /// array according to its role (authors, translators, etc.).
    ///
    /// - Parameters:
    ///   - element: The XML element to parse.
    ///   - metadata: The Metadata object.
    private func parseContributor(from element: XMLElement, to metadata: inout Metadata) {
        guard var contributor = createContributor(from: element) else {
            return
        }

        // Look up for possible meta refines for contributor's role.
        if let eid = element.attr("id") {
            contributor.roles.append(
                contentsOf: metas["role", refining: eid].map { $0.content }
            )
        }
        
        // Add the contributor to the proper property according to its `roles`
        if !contributor.roles.isEmpty {
            for role in contributor.roles {
                switch role {
                case "aut":
                    metadata.authors.append(contributor)
                case "trl":
                    metadata.translators.append(contributor)
                case "art":
                    metadata.artists.append(contributor)
                case "edt":
                    metadata.editors.append(contributor)
                case "ill":
                    metadata.illustrators.append(contributor)
                case "clr":
                    metadata.colorists.append(contributor)
                case "nrt":
                    metadata.narrators.append(contributor)
                case "pbl":
                    metadata.publishers.append(contributor)
                default:
                    metadata.contributors.append(contributor)
                }
            }
        } else {
            // No role, so do the branching using the element.name.
            // The remaining ones go to to the contributors.
            if element.tag == "creator" || element.attr("property") == "dcterms:creator" {
                metadata.authors.append(contributor)
            } else if element.tag == "publisher" || element.attr("property") == "dcterms:publisher" {
                metadata.publishers.append(contributor)
            } else {
                metadata.contributors.append(contributor)
            }
        }
    }

    /// Builds a `Contributor` instance from a `<dc:creator>`, `<dc:contributor>`
    /// or <dc:publisher> element, or <meta> element with property == "dcterms:
    /// creator", "dcterms:publisher", "dcterms:contributor".
    ///
    /// - Parameters:
    ///   - element: The XML element reprensenting the contributor.
    /// - Returns: The newly created Contributor instance.
    private func createContributor(from element: XMLElement) -> Contributor? {
        guard let name = localizedString(for: element) else {
            return nil
        }
        
        return Contributor(
            name: name,
            sortAs: element.attr("file-as"),
            role: element.attr("role")
        )
    }

    private lazy var readingProgression: ReadingProgression = {
        let direction = document.firstChild(xpath: "/opf:package/opf:readingOrder|/opf:package/opf:spine")?.attr("page-progression-direction") ?? "default"
        switch direction {
        case "ltr":
            return .ltr
        case "rtl":
            return .rtl
        case "default":
            return .auto
        default:
            return .auto
        }
    }()

    /// Return a localized string, defining the multiple representations of a string in different languages.
    ///
    /// - Parameters:
    ///   - element: The element to parse (can be a title or a contributor).
    private func localizedString(for element: XMLElement?) -> LocalizedString? {
        guard let element = element else {
            return nil
        }
        
        var strings: [String: String] = [:]
        
        // Default string
        let defaultString = element.stringValue
        guard let defaultLanguage =  language(for: element) else {
            return defaultString.localizedString
        }
        strings[defaultLanguage] = defaultString

        // Finds translations
        if let elementID = element.attr("id") {
            // Find the <meta refines="elementId" property="alternate-script"> in order to find the alternative strings, if any.
            for altScriptMeta in metas["alternate-script", refining: elementID] {
                // If it have a value then add it to the translations dictionnary.
                let value = altScriptMeta.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, let lang = altScriptMeta.element.attr("lang") else {
                    continue
                }
                strings[lang] = value
            }
        }
        
        if strings.count > 1 {
            return strings.localizedString
        } else {
            return strings.first?.value.localizedString
        }
    }
    
}
