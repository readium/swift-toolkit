//
//  MetadataParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/17/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import AEXML

extension MetadataParser: Loggable {}

final public class MetadataParser {

    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    ///
    /// - Parameters:
    ///   - metadata: The XML element containing the metadatas.
    ///   - displayOptions: Parsed iBooks or Kobo display options document. Used as a fallback.
    static internal func parseRenditionProperties(from metadata: AEXMLElement, displayOptions: AEXMLDocument?) -> EPUBRendition {

        func meta(_ property: String) -> String {
            return metadata["meta"].all?
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
            layout: {
                switch meta("rendition:layout") {
                case "reflowable":
                    return .reflowable
                case "pre-paginated":
                    return .fixed
                default:
                    if displayOption("fixed-layout") == "true" {
                        return .fixed
                    }
                    return .reflowable
                }
            }(),
            
            orientation: {
                switch meta("rendition:orientation") {
                case "landscape":
                    return .landscape
                case "portrait":
                    return .portrait
                case "auto":
                    return .auto
                default:
                    if let orientationLock = displayOption("orientation-lock", platform: "*")
                        ?? displayOption("orientation-lock", platform: "ipad")
                        ?? displayOption("orientation-lock", platform: "iphone") {
                        switch orientationLock {
                        case "none":
                            return .auto
                        case "landscape-only":
                            return .landscape
                        case "portrait-only":
                            return .portrait
                        default:
                            return .auto
                        }
                    }
                    return .auto
                }
            }(),
            
            overflow: {
                switch meta("rendition:flow") {
                case "auto":
                    return .auto
                case "paginated":
                    return .paginated
                case "scrolled-doc":
                    return .scrolled
                case "scrolled-continous":
                    return .scrolledContinuous
                default:
                    return .auto
                }
            }(),
            
            spread: {
                switch meta("rendition:spread") {
                case "none":
                    return .none
                case "auto":
                    return .auto
                case "landscape":
                    return .landscape
                // `portrait` is deprecated and should fallback to `both`.
                // See. https://readium.org/architecture/streamer/parser/metadata#epub-3x-11
                case "both", "portrait":
                    return .both
                default:
                    return .auto
                }
            }()
        )
    }

    /// Parse and return the title informations for different title types
    /// of the publication the from the OPF XML document `<metadata>` element.
    /// In the simplest cases it just return the value of the <dc:title> XML 
    /// element, but sometimes there are alternative titles (titles in other
    /// languages).
    /// See `MultilangString` for complementary informations.
    ///
    /// - Parameter metadata: The `<metadata>` element.
    /// - Returns: The content of the `<dc:title>` element, `nil` if the element
    ///            wasn't found.
    static internal func titleFor(titleType: EPUBTitleType, from metadata: AEXMLElement) -> LocalizedString? {
        // Return if there isn't any `<dc:title>` element
        guard let titles = metadata["dc:title"].all,
            let titleElement = getTitleElement(titleType: titleType, from: titles, metadata) else
        {
            log(.error, "Error: Publication have no title")
            return nil
        }
        
        if let localizedTitle = multiString(forElement: titleElement, metadata) {
            return localizedTitle.localizedString
        } else if !titleElement.string.isEmpty {
            return titleElement.string.localizedString
        } else {
            return nil
        }
    }
    
    static internal func mainTitle(from metadata: AEXMLElement) -> LocalizedString? {
        guard let mainTitle = titleFor(titleType: .main, from: metadata) else {
            /// Recovers using any other title, when there is no title marked as main title.
            let title = metadata["dc:title"].string
            return title.isEmpty ? nil : title.localizedString
        }
        return mainTitle
    }
    
    static internal func subTitle(from metadata: AEXMLElement) -> LocalizedString? {
        return titleFor(titleType: .subtitle, from: metadata)
    }

    /// Parse and return the Epub unique identifier.
    ///
    /// - Parameters:
    ///   - metadata: The metadata XML element.
    ///   - Attributes: The XML document attributes.
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the
    ///            element wasn't found.
    static internal func uniqueIdentifier(from document: AEXMLElement) -> String?
    {
        let metadata = document["package"]["metadata"]
        let attributes = document["package"].attributes
        
        // Look for `<dc:identifier>` elements.
        guard let identifiers = metadata["dc:identifier"].all else {
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
    /// - Parameters:
    ///   - metadataElement: The XML element representing the Publication Metadata.
    /// - Returns: The date generated from the <dcterms:modified> meta element,
    ///            or nil if not found.
    static internal func modifiedDate(from metadataElement: AEXMLElement) -> Date? {
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
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element representing the metadata.
    static internal func subjects(from metadataElement: AEXMLElement) -> [Subject]
    {
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
    ///   - metadataElement: The XML element representing the metadata.
    ///   - metadata: The Metadata object to fill (inout).
    ///   - epubVersion: The version of the epub document being parsed.
    static internal func parseContributors(from metadataElement: AEXMLElement,
                                    to metadata: inout Metadata,
                                    _ epubVersion: Double?)
    {
        var allContributors = [AEXMLElement]()


        allContributors.append(contentsOf: findContributorsXmlElements(in: metadataElement))
        // <meta> DCTERMS parsing if epubVersion == 3.0.
        if epubVersion == 3.0 {
            allContributors.append(contentsOf: findContributorsMetaXmlElements(in: metadataElement))
        }
        // Parse XML elements and fill the metadata object.
        for contributor in allContributors {
            parseContributor(from: contributor, in: metadataElement, to: &metadata)
        }
    }

    /// Parse a `creator`, `contributor`, `publisher` element from the OPF XML
    /// document, then builds and adds a Contributor to the metadata, to an
    /// array according to its role (authors, translators, etc.).
    ///
    /// - Parameters:
    ///   - element: The XML element to parse.
    ///   - metadataElement: The XML element containing the metadata informations.
    ///   - metadata: The Metadata object.
    ///   - epubVersion: The version of the epub being parsed.
    static internal func parseContributor(from element: AEXMLElement, in metadataElement: AEXMLElement,
                                   to metadata: inout Metadata)
    {
        guard var contributor = createContributor(from: element, metadataElement) else {
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
        // Add the contributor to the proper property according to the its `roles`
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
            if element.name == "dc:creator" || element.attributes["property"] == "dcterms:contributor" {
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
    static internal func createContributor(from element: AEXMLElement, _ metadata: AEXMLElement) -> Contributor?
    {
        guard let name: LocalizedStringConvertible = multiString(forElement: element, metadata) ?? element.value else {
            return nil
        }
        
        return Contributor(
            name: name,
            sortAs: element.attributes["opf:file-as"],
            role: element.attributes["opf:role"]
        )
    }

    /// Parse the metadata>meta>property=media:duration elements from the
    /// metadata. These meta are related to the Media Overlays, they give the
    /// smil file audio playback time.
    /// Metadata -> e.g. : ["#smil-1": "00:01:24.687"]
    ///
    /// - Parameter document: The OPF XML element.
    /// - Returns: Mapping between the SMIL ID and its duration.
    static internal func parseMediaDurations(from document: AEXMLElement) -> [String: Double]
    {
        guard let metas = document["package"]["metadata"]["meta"].all else {
            return [:]
        }
        
        return metas
            .filter { $0.attributes["property"] == "media:duration" }
            .reduce([:]) { durations, item in
                var durations = durations
                if let property = item.attributes["refines"],
                    let value = item.value,
                    let duration = Double(SMILParser.smilTimeToSeconds(value))
                {
                    durations[property] = duration
                }

                return durations
            }
    }
    
    static internal func parseReadingProgression(from document: AEXMLElement) -> ReadingProgression {
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
    
    static internal func publishedDate(from metadata: AEXMLElement) -> Date? {
        // From the EPUB 2 and EPUB 3 specifications, only the `dc:date` element without any attribtes will be considered for the `published` property.
        // And only the string with full date will be considered as valid date string. The string format validation happens in the `setter` of `published`.
        return (metadata["dc:date"].all ?? [])
            .first { $0.attributes.count == 0 }?
            .value?
            .dateFromISO8601
    }

    // Mark: - Private Methods.
    
    /// Return the XML element corresponding to the specific title type
    /// `<meta refines="#.." property="title-type" id="title-type">titleType</meta>`
    ///
    /// - Parameters:
    ///   - titleType: the Type of title, see TitleType for more information.
    ///   - titles: The titles XML elements array.
    ///   - metadata: The Publication Metadata XML object.
    /// - Returns: The main title XML element.
    
    static private func getTitleElement(titleType:EPUBTitleType, from titles: [AEXMLElement],
                                        _ metadata: AEXMLElement) -> AEXMLElement?
    {
        return titles.first(where: {
            guard let eid = $0.attributes["id"] else {
                return false
            }
            let attributes = ["refines": "#\(eid)", "property": "title-type"]
            let metas = metadata["meta"].all(withAttributes: attributes)
            // For example, titleType.rawValue is "main"
            return metas?.contains(where: { $0.string == titleType.rawValue }) ?? false
        })
    }
    
    /// [EPUB 2.0 & 3.1+]
    /// Return the XML elements about the contributors.
    /// E.g.: `<dc:publisher "property"=".." >value<\>`.
    ///
    /// - Parameter metadata: The XML metadata element.
    /// - Returns: The array of XML element representing the contributors.
    static private func findContributorsXmlElements(in metadata: AEXMLElement) -> [AEXMLElement] {
        var allContributors = [AEXMLElement]()

        // Get the Publishers XML elements.
        if let publishers = metadata["dc:publisher"].all {
            allContributors.append(contentsOf: publishers)
        }
        // Get the Creators XML elements.
        if let creators = metadata["dc:creator"].all {
            allContributors.append(contentsOf: creators)
        }
        // Get the Contributors XML elements.
        if let contributors = metadata["dc:contributor"].all {
            allContributors.append(contentsOf: contributors)
        }
        return allContributors
    }

    /// [EPUB 3.0]
    /// Return the XML elements about the contributors.
    /// E.g.: `<meta "property"="dcterms:publisher/creator/contributor"`.
    ///
    /// - Parameter metadata: The metadata XML element.
    /// - Returns: The array of XML element representing the <meta> contributors.
    static private func findContributorsMetaXmlElements(in metadata: AEXMLElement) -> [AEXMLElement] {
        var allContributors = [AEXMLElement]()

        // Get the Publishers XML elements.
        let publisherAttributes = ["property": "dcterms:publisher"]
        if let publishersFromMeta = metadata["meta"].all(withAttributes: publisherAttributes),
            !publishersFromMeta.isEmpty {
            allContributors.append(contentsOf: publishersFromMeta)
        }
        // Get the Creators XML elements.
        let creatorAttributes = ["property": "dcterms:creator"]
        if let creatorsFromMeta = metadata["meta"].all(withAttributes: creatorAttributes),
            !creatorsFromMeta.isEmpty {
            allContributors.append(contentsOf: creatorsFromMeta)
        }
        // Get the Contributors XML elements.
        let contributorAttributes = ["property": "dcterms:contributor"]
        if let contributorsFromMeta = metadata["meta"].all(withAttributes: contributorAttributes),
            !contributorsFromMeta.isEmpty {
            allContributors.append(contentsOf: contributorsFromMeta)
        }
        return allContributors
    }

    /// Return an array of lang:string, defining the multiple representations of
    /// a string in different languages.
    ///
    /// - Parameters:
    ///   - element: The element to parse (can be a title or a contributor).
    ///   - metadata: The metadata XML element.
    static private func multiString(forElement element: AEXMLElement, _ metadata: AEXMLElement) -> [String: String]?
    {
        guard let elementId = element.attributes["id"] else {
            return nil
        }
        // Find the <meta refines="elementId" property="alternate-script">
        // in order to find the alternative strings, if any.
        let attr = ["refines": "#\(elementId)", "property": "alternate-script"]
        guard let altScriptMetas = metadata["meta"].all(withAttributes: attr) else {
            return nil
        }
        
        var multiString = [String:String]()
        // For each alt meta element.
        for altScriptMeta in altScriptMetas {
            // If it have a value then add it to the multiString dictionnary.
            guard let title = altScriptMeta.value,
                let lang = altScriptMeta.attributes["xml:lang"] else {
                    continue
            }
            multiString[lang] = title
        }
        // If we have 'alternates'...
        if !multiString.isEmpty {
            let publicationDefaultLanguage = metadata["dc:language"].value ?? ""
            let lang = element.attributes["xml:lang"] ?? publicationDefaultLanguage
            let value = element.value

            // Add the main element to the dictionnary.
            multiString[lang] = value
        }
        return multiString.isEmpty ? nil : multiString
    }
}
