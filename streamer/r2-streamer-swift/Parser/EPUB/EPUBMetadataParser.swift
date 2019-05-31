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
import AEXML


final class EPUBMetadataParser: Loggable {
    
    private let document: AEXMLDocument
    private let displayOptions: AEXMLDocument?

    init(document: AEXMLDocument, displayOptions: AEXMLDocument?) {
        self.document = document
        self.displayOptions = displayOptions
    }
    
    private lazy var metadataElement: AEXMLElement = {
        return document["package"]["metadata"]
    }()
    
    /// Parses the Metadata in the XML <metadata> element.
    func parse() throws -> Metadata {
        guard let title = mainTitle else {
            throw OPFParserError.missingPublicationTitle
        }
        
        var otherMetadata: [String: Any] = [:]
        if let source = parseMetadata(named: "dc:source") {
            otherMetadata["source"] = source
        }
        if let rights = parseMetadata(named: "dc:rights") {
            otherMetadata["rights"] = rights
        }
        
        var metadata = Metadata(
            identifier: uniqueIdentifier,
            title: title,
            subtitle: subtitle,
            modified: modifiedDate,
            published: publishedDate,
            languages: metadataElement["dc:language"].all?.map { $0.string } ?? [],
            subjects: subjects,
            readingProgression: readingProgression,
            description: metadataElement["dc:description"].value,
            otherMetadata: otherMetadata
        )
        parseContributors(to: &metadata)
        metadata.rendition = rendition

        return metadata
    }
    
    /// Parses a metadata element as JSON.
    func parseMetadata(named name: String) -> Any? {
        guard let values = metadataElement[name].all?
            .map({ $0.string.trimmingCharacters(in: .whitespacesAndNewlines) }) else
        {
            return nil
        }
        return values.count > 1 ? values : values.first
    }

    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    private var rendition: EPUBRendition {
        func meta(_ property: String) -> String {
            return metadataElement["meta"].all?
                .first { $0.attributes["property"] == property }?
                .string ?? ""
        }

        func displayOption(_ name: String, platform: String? = nil) -> String? {
            var element = displayOptions?.root
            if let platform = platform {
                element = element?.firstDescendant(where: { $0.name == "platform" && $0.attributes["name"] == platform })
            }
            return element?
                .firstDescendant(where: { $0.name == "option" && $0.attributes["name"] == name })?
                .string
        }

        return EPUBRendition(
            layout: .init(
                epub: meta("rendition:layout"),
                fallback: (displayOption("fixed-layout") == "true") ? .fixed : nil
            ),
            orientation: .init(
                epub: meta("rendition:orientation"),
                fallback: {
                    let orientationLock = displayOption("orientation-lock", platform: "*")
                        ?? displayOption("orientation-lock", platform: "ipad")
                        ?? displayOption("orientation-lock", platform: "iphone")
                        ?? ""
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
            overflow: .init(epub: meta("rendition:flow")),
            spread: .init(epub: meta("rendition:spread"))
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
        guard let titles = metadataElement["dc:title"].all,
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
    private func titleElement(for titleType: EPUBTitleType, from titles: [AEXMLElement]) -> AEXMLElement? {
        return titles.first(where: {
            guard let eid = $0.attributes["id"] else {
                return false
            }
            let attributes = ["refines": "#\(eid)", "property": "title-type"]
            let metas = metadataElement["meta"].all(withAttributes: attributes)
            // For example, titleType.rawValue is "main"
            return metas?.contains(where: { $0.string == titleType.rawValue }) ?? false
        })
    }
    
    private var mainTitle: LocalizedString? {
        return title(for: .main)
            /// Recovers using any other title, when there is no title marked as main title.
            ?? localizedString(for: metadataElement["dc:title"])
    }
    
    private var subtitle: LocalizedString? {
        return title(for: .subtitle)
    }

    /// Parse and return the Epub unique identifier.
    ///
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the element wasn't found.
    private var uniqueIdentifier: String? {
        let attributes = document["package"].attributes
        
        // Look for `<dc:identifier>` elements.
        guard let identifiers = metadataElement["dc:identifier"].all else {
            return nil
        }
        // Get the one defined as unique by the `<package>` attribute `unique-identifier`.
        if identifiers.count > 1, let uniqueId = attributes["unique-identifier"] {
            let uniqueIdentifiers = identifiers.filter { $0.attributes["id"] == uniqueId }
            if !uniqueIdentifiers.isEmpty, let uid = uniqueIdentifiers.first {
                return uid.string
            }
        }
        // Returns the first `<dc:identifier>` content or an empty String.
        return identifiers[0].string
    }

    /// Parse the modifiedDate (date of last modification of the EPUB).
    ///
    /// - Returns: The date generated from the <dcterms:modified> meta element,
    ///            or nil if not found.
    private var modifiedDate: Date? {
        let modifiedAttribute = ["property" : "dcterms:modified"]

        // Search if the XML element is present, else return.
        guard let modified = metadataElement["meta"].all(withAttributes: modifiedAttribute),
            !modified.isEmpty else
        {
            return nil
        }
        let iso8601DateString = modified[0].string

        // Convert the XML element ISO8601DateString into a Date.
        // See Formatter/Date/String extensions for details.
        guard let dateFromString = iso8601DateString.dateFromISO8601 else {
            log(.warning, "Error converting the modifiedDate to a Date object")
            return nil
        }
        return dateFromString
    }

    /// Parse the <dc:subject> XML element from the metadata
    private var subjects: [Subject] {
        return (metadataElement["dc:subject"].all ?? [])
            .compactMap { element in
                guard let name = element.value else {
                    log(.warning, "Invalid Epub, no value for <dc:subject>")
                    return nil
                }
                return Subject(
                    name: name,
                    scheme: element.attributes["opf:authority"],
                    code: element.attributes["opf:term"]
                )
            }
    }

    /// Parse all the Contributors objects of the model (`creator`, `contributor`,
    /// `publisher`) and add them to the metadata.
    ///
    /// - Parameters:
    ///   - metadata: The Metadata object to fill (inout).
    private func parseContributors(to metadata: inout Metadata) {
        var allContributors = [AEXMLElement]()

        allContributors.append(contentsOf: findContributorMetaElements())
        allContributors.append(contentsOf: findContributorElements())
        
        // Parse XML elements and fill the metadata object.
        for contributor in allContributors {
            parseContributor(from: contributor, to: &metadata)
        }
    }

    /// [EPUB 2.0 & 3.1+]
    /// Return the XML elements about the contributors.
    /// E.g.: `<dc:publisher "property"=".." >value<\>`.
    ///
    /// - Parameter metadata: The XML metadata element.
    /// - Returns: The array of XML element representing the contributors.
    private func findContributorElements() -> [AEXMLElement] {
        var allContributors = [AEXMLElement]()
        
        // Get the Creators XML elements.
        if let creators = metadataElement["dc:creator"].all {
            allContributors.append(contentsOf: creators)
        }
        // Get the Publishers XML elements.
        if let publishers = metadataElement["dc:publisher"].all {
            allContributors.append(contentsOf: publishers)
        }
        
        // Get the Contributors XML elements.
        if let contributors = metadataElement["dc:contributor"].all {
            allContributors.append(contentsOf: contributors)
        }
        return allContributors
    }

    /// [EPUB 3.0]
    /// Return the XML elements about the contributors.
    /// E.g.: `<meta property="dcterms:publisher/creator/contributor"`.
    ///
    /// - Returns: The array of XML element representing the <meta> contributors.
    private func findContributorMetaElements() -> [AEXMLElement] {
        var allContributors = [AEXMLElement]()
        
        // Get the Creators XML elements.
        let creatorAttributes = ["property": "dcterms:creator"]
        if let creatorsFromMeta = metadataElement["meta"].all(withAttributes: creatorAttributes),
            !creatorsFromMeta.isEmpty {
            allContributors.append(contentsOf: creatorsFromMeta)
        }
        // Get the Publishers XML elements.
        let publisherAttributes = ["property": "dcterms:publisher"]
        if let publishersFromMeta = metadataElement["meta"].all(withAttributes: publisherAttributes),
            !publishersFromMeta.isEmpty {
            allContributors.append(contentsOf: publishersFromMeta)
        }
        // Get the Contributors XML elements.
        let contributorAttributes = ["property": "dcterms:contributor"]
        if let contributorsFromMeta = metadataElement["meta"].all(withAttributes: contributorAttributes),
            !contributorsFromMeta.isEmpty {
            allContributors.append(contentsOf: contributorsFromMeta)
        }
        return allContributors
    }

    /// Parse a `creator`, `contributor`, `publisher` element from the OPF XML
    /// document, then builds and adds a Contributor to the metadata, to an
    /// array according to its role (authors, translators, etc.).
    ///
    /// - Parameters:
    ///   - element: The XML element to parse.
    ///   - metadata: The Metadata object.
    private func parseContributor(from element: AEXMLElement, to metadata: inout Metadata) {
        guard var contributor = createContributor(from: element) else {
            return
        }

        // Look up for possible meta refines for contributor's role.
        if let eid = element.attributes["id"] {
            let attributes = ["refines": "#\(eid)", "property": "role"]
            if let metas = metadataElement["meta"].all(withAttributes: attributes) {
                for element in metas {
                    if let role = element.value {
                        contributor.roles.append(role)
                    }
                }
            }
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
            if element.name == "dc:creator" || element.attributes["property"] == "dcterms:creator" {
                metadata.authors.append(contributor)
            } else if element.name == "dc:publisher" || element.attributes["property"] == "dcterms:publisher" {
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
    private func createContributor(from element: AEXMLElement) -> Contributor? {
        guard let name = localizedString(for: element) else {
            return nil
        }
        
        return Contributor(
            name: name,
            sortAs: element.attributes["opf:file-as"],
            role: element.attributes["opf:role"]
        )
    }

    private var readingProgression: ReadingProgression {
        let direction = document["package"]["readingOrder"].attributes["page-progression-direction"]
            ?? document["package"]["spine"].attributes["page-progression-direction"]
            ?? "default"

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
        return (metadataElement["dc:date"].all ?? [])
            .first { $0.attributes.count == 0 }?
            .value?
            .dateFromISO8601
    }

    /// Return a localized string, defining the multiple representations of a string in different languages.
    ///
    /// - Parameters:
    ///   - element: The element to parse (can be a title or a contributor).
    private func localizedString(for element: AEXMLElement?) -> LocalizedString? {
        guard let element = element else {
            return nil
        }
        
        var strings: [String: String] = [:]
        
        // Default string
        if let value = element.value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            let publicationDefaultLanguage = metadataElement["dc:language"].value ?? ""
            let lang = element.attributes["xml:lang"] ?? publicationDefaultLanguage
            strings[lang] = value
        }

        // Finds translations
        if let elementId = element.attributes["id"] {
            // Find the <meta refines="elementId" property="alternate-script">
            // in order to find the alternative strings, if any.
            let attr = ["refines": "#\(elementId)", "property": "alternate-script"]
            guard let altScriptMetas = metadataElement["meta"].all(withAttributes: attr) else {
                return nil
            }
    
            // For each alt meta element.
            for altScriptMeta in altScriptMetas {
                // If it have a value then add it to the translations dictionnary.
                guard let value = altScriptMeta.value?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !value.isEmpty,
                    let lang = altScriptMeta.attributes["xml:lang"] else
                {
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
