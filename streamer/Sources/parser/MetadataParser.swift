//
//  MetadataParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import R2Shared
import AEXML

extension MetadataParser: Loggable {}

final public class MetadataParser {

    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element containing the metadatas.
    ///   - metadata: The `Metadata` object.
    static internal func parseRenditionProperties(from metadataElement: AEXMLElement,
                                           to metadata: inout Metadata) {
        guard let metas = metadataElement["meta"].all else {
            metadata.rendition.layout = RenditionLayout.reflowable
            return
        }
        // TODO: factorize
        // Layout
        if let renditionLayout = metas.first(where: { $0.attributes["property"] == "rendition:layout" }) {
            let layout = renditionLayout.string

            metadata.rendition.layout = RenditionLayout(rawValue: layout)
        } else {
            metadata.rendition.layout = RenditionLayout.reflowable
        }
        // Flow
        if let renditionFlow = metas.first(where: { $0.attributes["property"] == "rendition:flow" }) {
            let flow = renditionFlow.string

            metadata.rendition.flow = RenditionFlow(rawValue: flow)
        }
        // Orientation
        if let renditionOrientation = metas.first(where: { $0.attributes["property"] == "rendition:orientation" }) {
            let orientation = renditionOrientation.string

            metadata.rendition.orientation = RenditionOrientation(rawValue: orientation)
        }
        // Spread
        if let renditionSpread = metas.first(where: { $0.attributes["property"] == "rendition:spread" }) {
            let spread = renditionSpread.string

            metadata.rendition.spread = RenditionSpread(rawValue: spread)
        }
        // Viewport
        if let renditionViewport = metas.first(where: { $0.attributes["property"] == "rendition:viewport" }) {
            metadata.rendition.viewport = renditionViewport.string
        }
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
    
    static internal func titleFor(titleType: EPUBTitleType, from metadata: AEXMLElement) -> MultilangString? {
        // Return if there isn't any `<dc:title>` element
        guard let titles = metadata["dc:title"].all else {
            log(level: .error, "Error: Publication have no title")
            return nil
        }
        
        let multilangTitle = MultilangString()
        
        guard let titleElement = getTitleElement(titleType: titleType, from: titles, metadata) else {
            return multilangTitle
        }
        /// Get single title from filtered xml element
        multilangTitle.singleString = titleElement.string
        /// Now trying to see if multiString title (multi lang).
        multilangTitle.multiString = multiString(forElement: titleElement, metadata)
        return multilangTitle
    }
    
    static internal func mainTitle(from metadata: AEXMLElement) -> MultilangString? {
        
        guard let mainTitle = titleFor(titleType: .main, from: metadata) else {return nil}
        
        /// The default title to be returned, the first one, singleString.
        /// Special treatment for main title when there is no title marked as main title.
        if mainTitle.singleString == nil {
            mainTitle.singleString = metadata["dc:title"].string
        }
        return mainTitle
    }
    
    static internal func subTitle(from metadata: AEXMLElement) -> MultilangString? {
        
        return titleFor(titleType: .subtitle, from: metadata)
    }

    /// Parse and return the Epub unique identifier.
    ///
    /// - Parameters:
    ///   - metadata: The metadata XML element.
    ///   - Attributes: The XML document attributes.
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the
    ///            element wasn't found.
    static internal func uniqueIdentifier(from metadata: AEXMLElement,
                                   with documentattributes: [String : String]) -> String?
    {
        // Look for `<dc:identifier>` elements.
        guard let identifiers = metadata["dc:identifier"].all else {
            return nil
        }
        // Get the one defined as unique by the `<package>` attribute `unique-identifier`.
        if identifiers.count > 1, let uniqueId = documentattributes["unique-identifier"] {
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
            log(level: .warning, "Error converting the modifiedDate to a Date object")
            return nil
        }
        return dateFromString
    }

    /// Parse the <dc:subject> XML element from the metadata
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element representing the metadata.
    ///   - metadata: The Metadata object to fill (inout).
    static internal func subject(from metadataElement: AEXMLElement) -> Subject?
    {
        /// Find the first <dc:subject> (Epub 3.1)
        guard let subjectElement = metadataElement["dc:subject"].first else {
            return nil
        }
        /// Check if there is a value, mandatory field.
        guard let name = subjectElement.value else {
            log(level: .warning, "Invalid Epub, no value for <dc:subject>")
            return nil
        }
        let subject = Subject()

        subject.name = name
        subject.scheme = subjectElement.attributes["opf:authority"]
        subject.code = subjectElement.attributes["opf:term"]
        return subject
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
        let contributor = createContributor(from: element, metadataElement)

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
    static internal func createContributor(from element: AEXMLElement, _ metadata: AEXMLElement) -> Contributor
    {
        // The 'to be returned' Contributor object.
        let contributor = Contributor()

        /// The default title to be returned, the first one, singleString.
        contributor.multilangName.singleString = element.value
        contributor.multilangName.multiString = multiString(forElement: element, metadata)
        // Get role from role attribute
        if let role = element.attributes["opf:role"] {
            contributor.roles.append(role)
        }
        // Get sort name from file-as attribute
        if let sortAs = element.attributes["opf:file-as"] {
            contributor.sortAs = sortAs
        }
        return contributor
    }

    /// Parse the metadata>meta>property=media:duration elements from the
    /// metadata. These meta are related to the Media Overlays, they give the
    /// smil file audio playback time.
    /// Metadata -> e.g. : ["#smil-1": "00:01:24.687"]
    ///
    /// - Parameters:
    ///   - metadataElement: The Metadata XML element.
    ///   - otherMetadata: The publication's `otherMetadata` property.
    static internal func parseMediaDurations(from metadataElement: AEXMLElement,
                                      to otherMetadata: inout [MetadataItem])
    {
        guard let metas = metadataElement["meta"].all else {
            return
        }
        let mediaDurationItems = metas.filter({ $0.attributes["property"] == "media:duration" })
        guard !mediaDurationItems.isEmpty else {
            return
        }
        for mediaDurationItem in mediaDurationItems {
            let item = MetadataItem()

            item.property = mediaDurationItem.attributes["refines"]
            item.value = mediaDurationItem.value
            otherMetadata.append(item)
        }
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
    static private func multiString(forElement element: AEXMLElement,
                             _ metadata: AEXMLElement) -> [String: String]
    {
        var multiString = [String:String]()

        guard let elementId = element.attributes["id"] else {
            return multiString
        }
        // Find the <meta refines="elementId" property="alternate-script">
        // in order to find the alternative strings, if any.
        let attr = ["refines": "#\(elementId)", "property": "alternate-script"]
        guard let altScriptMetas = metadata["meta"].all(withAttributes: attr) else {
            return multiString
        }
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
        return multiString
    }
}
