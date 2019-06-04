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
            subjects: subjects,
            readingProgression: readingProgression,
            description: description,
            otherMetadata: metas.otherMetadata
        )
        parseContributors(to: &metadata)
        metadata.rendition = rendition

        return metadata
    }
    
    /// Parses a metadata element as JSON.

    private var languages: [String] {
        return metadataElement?.xpath("dc:language").map { $0.stringValue } ?? []
    }
    
    private var description: String? {
        return metadataElement?.xpath("dc:description").first?.stringValue
    }
    
    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    private var rendition: EPUBRendition {
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
    }

    /// Parse and return the title informations for different title types
    /// of the publication the from the OPF XML document `<metadata>` element.
    /// In the simplest cases it just return the value of the <dc:title> XML 
    /// element, but sometimes there are alternative titles (titles in other
    /// languages).
    /// See `MultilangString` for complementary informations.
    ///
    /// - Returns: The content of the `<dc:title>` element, `nil` if the element
    ///            wasn't found.
    private func title(for titleType: EPUBTitleType) -> LocalizedString? {
        // Return if there isn't any `<dc:title>` element
        guard let titles = metadataElement?.xpath("dc:title"),
            let titleElement = titleElement(for: titleType, from: titles) else
        {
            return nil
        }
        
        return localizedString(for: titleElement)
    }

    /// Return the XML element corresponding to the specific title type
    /// `<meta refines="#.." property="title-type" id="title-type">titleType</meta>`
    ///
    /// - Parameters:
    ///   - titleType: the Type of title, see TitleType for more information.
    ///   - titles: The titles XML elements array.
    /// - Returns: The main title XML element.
    private func titleElement(for titleType: EPUBTitleType, from titles: NodeSet) -> XMLElement? {
        return titles.first {
            guard let eid = $0.attr("id") else {
                return false
            }
            // For example, titleType.rawValue is "main"
            return metas["title-type", refining: eid].last?.content == titleType.rawValue
        }
    }
    
    private var mainTitle: LocalizedString? {
        return title(for: .main)
            /// Recovers using any other title, when there is no title marked as main title.
            ?? localizedString(for: metadataElement?.firstChild(xpath: "dc:title"))
    }
    
    private var subtitle: LocalizedString? {
        return title(for: .subtitle)
    }

    /// Parse and return the Epub unique identifier.
    ///
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the element wasn't found.
    private var uniqueIdentifier: String? {
        // Look for `<dc:identifier>` elements.
        guard let identifiers = metadataElement?.xpath("dc:identifier") else {
            return nil
        }
        
        // Gets the one defined as unique by the `<package>` attribute `unique-identifier` or fallback on the first one found.
        let uniqueIdentifierID = document.firstChild(xpath: "/opf:package")?.attr("unique-identifier") ?? ""
        let identifier = identifiers.first { $0.attr("id") == uniqueIdentifierID }
            ?? identifiers.first
        return identifier?.stringValue
    }

    /// Parse the modifiedDate (date of last modification of the EPUB).
    ///
    /// - Returns: The date generated from the <dcterms:modified> meta element,
    ///            or nil if not found.
    private var modifiedDate: Date? {
        return metas["modified", in: .dcterms]
            .compactMap { $0.content.dateFromISO8601 }
            .last
    }

    /// Parse the <dc:subject> XML element from the metadata
    private var subjects: [Subject] {
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
    }

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

    private var readingProgression: ReadingProgression {
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
    }
    
    private var publishedDate: Date? {
        // From the EPUB 2 and EPUB 3 specifications, only the `dc:date` element without any attribtes will be considered for the `published` property.
        // And only the string with full date will be considered as valid date string. The string format validation happens in the `setter` of `published`.
        return metadataElement?.xpath("dc:date")
            .first { $0.attributes.isEmpty }?
            .stringValue
            .dateFromISO8601
    }

    /// Return a localized string, defining the multiple representations of a string in different languages.
    ///
    /// - Parameters:
    ///   - element: The element to parse (can be a title or a contributor).
    private func localizedString(for element: XMLElement?) -> LocalizedString? {
        guard let metadataElement = metadataElement, let element = element else {
            return nil
        }
        
        var strings: [String: String] = [:]
        
        // Default string
        let value = element.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            let publicationDefaultLanguage = metadataElement.firstChild(xpath: "dc:language")?.stringValue ?? ""
            let lang = element.attr("lang") ?? publicationDefaultLanguage
            strings[lang] = value
        }

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
