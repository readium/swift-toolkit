//
//  MetadataParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import AEXML

extension MetadataParser: Loggable {}

public class MetadataParser {

    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element containing the metadatas.
    ///   - metadata: The `Metadata` object.
    internal func parseRenditionProperties(from metadataElement: AEXMLElement,
                                           to metadata: inout Metadata)
    {
        // Layout
        var attribute = ["property" : "rendition:layout"]

        if let renditionLayouts = metadataElement.all(withAttributes: attribute),
            !renditionLayouts.isEmpty {
            let layouts = renditionLayouts[0].string

            metadata.rendition.layout = RenditionLayout(rawValue: layouts)
        }
        // Flow
        attribute = ["property" : "rendition:flow"]
        if let renditionFlows = metadataElement.all(withAttributes: attribute),
            !renditionFlows.isEmpty {
            let flows = renditionFlows[0].string

            metadata.rendition.flow = RenditionFlow(rawValue: flows)
        }
        // Orientation
        attribute = ["property" : "rendition:orientation"]
        if let renditionOrientations = metadataElement.all(withAttributes: attribute),
            !renditionOrientations.isEmpty {
            let orientation = renditionOrientations[0].string

            metadata.rendition.orientation = RenditionOrientation(rawValue: orientation)
        }
        // Spread
        attribute = ["property" : "rendition:spread"]
        if let renditionSpreads = metadataElement.all(withAttributes: attribute),
            !renditionSpreads.isEmpty {
            let spread = renditionSpreads[0].string

            metadata.rendition.spread = RenditionSpread(rawValue: spread)
        }
        // Viewport
        attribute = ["property" : "rendition:viewport"]
        if let renditionViewports = metadataElement.all(withAttributes: attribute),
            !renditionViewports.isEmpty {
            metadata.rendition.viewport = renditionViewports[0].string
        }
    }

    /// Parse and return the main title of the publication from the from the OPF
    /// XML document `<metadata>` element.
    ///
    /// - Parameter metadata: The `<metadata>` element.
    /// - Returns: The content of the `<dc:title>` element, `nil` if the element
    ///            wasn't found.
    internal func mainTitle(from metadata: AEXMLElement, epubVersion: Double?) -> String? {
        // Return if there isn't any `<dc:title>` element
        guard let titles = metadata["dc:title"].all else {
            return nil
        }
        // If there's more than one, look for the `main` one as defined by
        // `refines`.
        // Else, as a fallback and default, return the first `<dc:title>`
        // content.
        guard titles.count > 1, epubVersion != nil, epubVersion! >= 3.0 else {
            return metadata["dc:title"].string
        }
        /// Used in the closure below.
        func isMainTitle(element: AEXMLElement) -> Bool {
            guard let eid = element.attributes["id"] else {
                return false
            }
            let attributes = ["property": "title-type", "refines": "#" + eid]
            let metas = metadata["meta"].all(withAttributes: attributes)

            return metas?.contains(where: { $0.string == "main" }) ?? false
        }
        // Returns the first main title encountered
        return titles.first(where: { isMainTitle(element: $0)})?.string
    }

    /// Parse and return the Epub unique identifier.
    ///
    /// - Parameters:
    ///   - metadata: The metadata XML element.
    ///   - Attributes: The XML document attributes.
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the
    ///             element wasn't found.
    internal func uniqueIdentifier(from metadata: AEXMLElement,
                                   withAttributes attributes: [String : String]) -> String?
    {
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
        return metadata["dc:identifier"].string
    }

    /// Parse the modifiedDate (date of last modification of the EPUB).
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element representing the Publication Metadata.
    /// - Returns: The date generated from the <dcterms:modified> meta element,
    ///            or nil if not found.
    internal func modifiedDate(from metadataElement: AEXMLElement) -> Date? {
        let modifiedAttribute = ["property" : "dcterms:modified"]

        // Search if the XML element is present, else return.
        guard let modified = metadataElement["meta"].all(withAttributes: modifiedAttribute) else {
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
    internal func subject(from metadataElement: AEXMLElement) -> Subject?
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
    /// `publisher`) then add them to the metadata.
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element representing the metadata.
    ///   - metadata: The Metadata object to fill (inout).
    ///   - epubVersion: The version of the epub document being parsed.
    internal func parseContributors(from metadataElement: AEXMLElement,
                                    to metadata: inout Metadata, with epubVersion: Double?)
    {
        var allContributors = [AEXMLElement]()

        // Publishers.
        if let publishers = metadataElement["dc:publisher"].all {
            allContributors.append(contentsOf: publishers)
        }
        // Creators.
        if let creators = metadataElement["dc:creator"].all {
            allContributors.append(contentsOf: creators)
        }
        // Contributors.
        if let contributors = metadataElement["dc:contributor"].all {
            allContributors.append(contentsOf: contributors)
        }
        // Heavy lifting.
        for contributor in allContributors {
            parseContributor(from: contributor, in: metadataElement, to: &metadata, with: epubVersion)
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
    internal func parseContributor(from element: AEXMLElement, in metadataElement: AEXMLElement,
                                   to metadata: inout Metadata, with epubVersion: Double?)
    {
        let contributor = createContributor(from: element)

        // Look up for possible meta refines for contributor's role.
        if epubVersion != nil, epubVersion! >= 3.0, let eid = element.attributes["id"] {
            let attributes = ["property": "role", "refines": "#\(eid)"]
            let metas = metadataElement["meta"].all(withAttributes: attributes)

            contributor.role = metas?.first?.string
        }
        // Add the contributor to the proper property according to the its `role`
        if let role = contributor.role {
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
        } else {
            // No role, so do the branching using the element.name.
            // The remaining ones go to to the contributors.
            if element.name == "dc:creator" {
                metadata.authors.append(contributor)
            } else if element.name == "dc:publisher" {
                metadata.publishers.append(contributor)
            }else {
                metadata.contributors.append(contributor)
            }
        }
    }

    /// Builds a `Contributor` instance from a `<dc:creator>`, `<dc:contributor>`
    /// or <dc:publisher> element.
    ///
    /// - Parameters:
    ///   - element: The XML element reprensenting the contributor.
    /// - Returns: The newly created Contributor instance.
    internal func createContributor(from element: AEXMLElement) -> Contributor
    {
        // The 'to be returned' Contributor object.
        let contributor = Contributor(name: element.string)

        // Get role from role attribute
        if let role = element.attributes["opf:role"] {
            contributor.role = role
        }
        // Get sort name from file-as attribute
        if let sortAs = element.attributes["opf:file-as"] {
            contributor.sortAs = sortAs
        }
        return contributor
    }
}
