//
//  OPFParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/21/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import AEXML

extension OPFParser: Loggable {}

enum OPFParserError: Error {
    /// The Epub have no title. Title is mandatory.
    case missingPublicationTitle
}

/// EpubParser support class, able to parse the OPF package document.
/// OPF: Open Packaging Format.
public class OPFParser {

    internal init() {}

    /// Parse the OPF file of the Epub container and return a `Publication`.
    /// It also complete the informations stored in the container.
    ///
    /// - Parameter container: The EPUB container whom OPF file will be parsed.
    /// - Returns: The `Publication` object resulting from the parsing.
    /// - Throws: `EpubParserError.xmlParse`.
    internal func parseOPF(from document: AEXMLDocument,
                           with container: EpubContainer,
                           and epubVersion: Double) throws -> Publication
    {
        /// The 'to be built' Publication.
        var publication = Publication()

        publication.epubVersion = epubVersion
        publication.internalData["type"] = "epub"
        publication.internalData["rootfile"] = container.rootFile.rootFilePath
        // Self link is added when the epub is being served (in the EpubServer).
        // CoverId.
        var coverId: String?
        if let coverMetas = document.root["metadata"]["meta"].all(withAttributes: ["name" : "cover"]) {
            coverId = coverMetas.first?.string
        }
        try parseMetadata(from: document, to: &publication)
        parseRessources(from: document.root["manifest"], to: &publication, coverId: coverId)
        parseSpine(from: document.root["spine"], to: &publication)
        try parseMediaOverlay(from: container, to: &publication)
        return publication
    }

    /// Parse the Metadata in the XML <metadata> element.
    ///
    /// - Parameter document: Parse the Metadata in the XML <metadata> element.
    /// - Returns: The Metadata object representing the XML <metadata> element.
    internal func parseMetadata(from document: AEXMLDocument, to publication: inout Publication) throws {
        /// The 'to be returned' Metadata object.
        var metadata = Metadata()
        let mp = MetadataParser()
        let metadataElement = document.root["metadata"]

        // Title.
        guard let multilangTitle = mp.mainTitle(from: metadataElement) else {
            throw OPFParserError.missingPublicationTitle
        }
        metadata._title = multilangTitle
        // Identifier.
        metadata.identifier = mp.uniqueIdentifier(from: metadataElement,
                                                  with: document.root.attributes)
        // Description.
        if let description = metadataElement["dc:description"].value {
            metadata.description = description
        }
        // Date. (year?)
        if let date = metadataElement["dc:date"].value {
            metadata.publicationDate = date
        }
        // Last modification date.
        metadata.modified = mp.modifiedDate(from: metadataElement)
        // Source.
        if let source = metadataElement["dc:source"].value {
            metadata.source = source
        }
        // Subject.
        if let subject = mp.subject(from: metadataElement) {
            metadata.subjects.append(subject)
        }
        // Languages.
        if let languages = metadataElement["dc:language"].all {
            metadata.languages = languages.map({ $0.string })
        }
        // Rights.
        if let rights = metadataElement["dc:rights"].all {
            metadata.rights = rights.map({ $0.string }).joined(separator: " ")
        }
        // Publishers, Creators, Contributors.
        let epubVersion = publication.epubVersion
        mp.parseContributors(from: metadataElement, to: &metadata, epubVersion)
        // Page progression direction.
        if let direction = document.root["spine"].attributes["page-progression-direction"] {
            metadata.direction = direction
        }
        // Rendition properties.
        mp.parseRenditionProperties(from: metadataElement["meta"], to: &metadata)
        publication.metadata = metadata
    }

    /// Parse XML elements of the <Manifest> in the package.opf file.
    /// Temporarily store the XML elements ids into the `.title` property of the
    /// `Link` created for each element.
    ///
    /// - Parameters:
    ///   - manifest: The Manifest XML element.
    ///   - publication: The `Publication` object with `.resource` properties to
    ///                  fill.
    ///   - coverId: The coverId to identify the cover ressource and tag it.
    internal func parseRessources(from manifest: AEXMLElement,
                                  to publication: inout Publication,
                                  coverId: String?)
    {
        // Get the manifest children items
        guard let manifestItems = manifest["item"].all else {
            log(level: .warning, "Manifest have no children elements.")
            return
        }
        /// Creates an Link for each of them and add it to the ressources.
        for item in manifestItems {
            // Add it to the manifest items dict if it has an id.
            guard let id = item.attributes["id"] else {
                log(level: .warning, "Manifest item MUST have an id, item ignored.")
                continue
            }
            let link = linkFromManifest(item)
            // If it's the cover's item id, set the rel to cover and add the link to `links`.
            if id == coverId {
                link.rel.append("cover")
            }
            // If the link's rel contains the cover tag, append it to the publication link
            if link.rel.contains("cover") {
                publication.links.append(link)
            }
            publication.resources.append(link)
        }
    }

    /// Parse XML elements of the <Spine> in the package.opf file.
    /// They are only composed of an `idref` referencing one of the previously
    /// parsed resource (XML: idref -> id). Since we normally don't keep
    /// the resource id, we store it in the `.title` property, temporarily.
    ///
    /// - Parameters:
    ///   - spine: The Spine XML element.
    ///   - publication: The `Publication` object with `.resource` and `.spine`
    ///                  properties to fill.
    internal func parseSpine(from spine: AEXMLElement, to publication: inout Publication) {
        // Get the spine children items.
        guard let spineItems = spine["itemref"].all else {
            log(level: .warning, "Spine have no children elements.")
            return
        }
        // Create a `Link` for each spine item and add it to `Publication.spine`.
        for item in spineItems {
            // Retrieve `idref`, referencing a resource id.
            // Only linear items are added to the spine.
            guard let idref = item.attributes["idref"],
                item.attributes["linear"]?.lowercased() != "no" else {
                    continue
            }
            // Find the ressource `idref` is referencing to.
            guard let index = publication.resources.index(where: { $0.title == idref }) else {
                log(level: .warning, "Referenced ressource for spine item with \(idref) not found.")
                continue
            }
            // Clean the title - used as a holder for the `idref`.
            publication.resources[index].title = nil
            // Move ressource to `.spine` and remove it from `.ressources`.
            publication.spine.append(publication.resources[index])
            publication.resources.remove(at: index)
        }
    }

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - container: <#container description#>
    ///   - publication: <#publication description#>
    /// - Throws: <#throws value description#>
    internal func parseMediaOverlay(from container: EpubContainer,
                                    to publication: inout Publication) throws
    {
        let mediaOverlays = publication.resources.filter({ $0.typeLink ==  "application/smil+xml"})
        guard !mediaOverlays.isEmpty else {
            log(level: .debug, "No media-overlays found in the Publication.")
            return
        }

        for mediaOverlayLink in mediaOverlays {
            let node = MediaOverlayNode()
            let smilXml = try container.xmlDocument(forRessourceReferencedByLink: mediaOverlayLink)
            let body = smilXml.root["Body"]

            node.role.append("section")
            node.text = body.attributes["epub:textref"]
            // get body parameters <par>
            parseParameters(in: body, withParent: node)
            parseSequences(in: body, withParent: node)

            // TO translate
            //            baseHref := strings.Split(mo.Text, "#")[0]
            //            link := findLinKByHref(publication, baseHref)
            //            link.MediaOverlays = append(link.MediaOverlays, mo)
            //            if link.Properties == nil {
            //                link.Properties = &models.Properties{MediaOverlay: mediaOverlayURL + link.Href}
            //            } else {
            //                link.Properties.MediaOverlay = mediaOverlayURL + link.Href
            //            }
        }
    }

    // MARK: - Fileprivate Methods.

    /// Generate a `Link` form the given manifest's XML element.
    ///
    /// - Parameter item: The XML element, or manifest XML item.
    /// - Returns: The `Link` representing the manifest XML item.
    fileprivate func linkFromManifest(_ item: AEXMLElement) -> Link {
        // The "to be built" link representing the manifest item.
        let link = Link()

        // TMP used for storing the id (associated to the idref of the spine items).
        // Will be cleared after the spine parsing.
        link.title = item.attributes["id"]
        //
        link.href = item.attributes["href"]
        link.typeLink = item.attributes["media-type"]
        // Look if item have any properties.
        if let propertyAttribute = item.attributes["properties"] {
            let ws = CharacterSet.whitespaces
            let properties = propertyAttribute.components(separatedBy: ws)

            // TODO: The contains "math/js" like in the Go streamer.
            // + refactor below.
            if properties.contains("nav") {
                link.rel.append("contents")
            }
            // If it's a cover, set the rel to cover and add the link to `links`
            if properties.contains("cover-image") {
                link.rel.append("cover")
            }
            let otherProperties = properties.filter { $0 != "cover-image" && $0 != "nav" }
            link.properties.append(contentsOf: otherProperties)
            // TODO: rendition properties
        }
        return link
    }
}

// MARK: - Media Overlays.
extension OPFParser {
    /// Parse the <par> elements at the current XML element level.
    ///
    /// - Parameters:
    ///   - element: The XML element which should contain <par>.
    ///   - parent: The parent MediaOverlayNode of the "to be creatred" nodes.
    fileprivate func parseParameters(in element: AEXMLElement,
                                     withParent parent: MediaOverlayNode)
    {
        guard let parameterElements = element["par"].all,
            !parameterElements.isEmpty else
        {
            return
        }
        // For each <par> in the current scope.
        for parameterElement in parameterElements {
            let newNode = MediaOverlayNode()

            guard let audioElement = parameterElement["audio"].first else {
                return
            }
            newNode.audio = parse(audioElement: audioElement)
            newNode.text = parameterElement.attributes["src"]
            parent.children.append(newNode)
        }
    }

    /// [RECURSIVE]
    /// Parse the <seq> elements at the current XML level. It will recursively
    /// parse they childrens <par> and <seq>
    ///
    /// - Parameters:
    ///   - element: The XML element which should contain <seq>.
    ///   - parent: The parent MediaOverlayNode of the "to be creatred" nodes.
    fileprivate func parseSequences(in element: AEXMLElement,
                                    withParent parent: MediaOverlayNode)
    {
        guard let sequenceElements = element["seq"].all,
            !sequenceElements.isEmpty else
        {
            return
        }
        for sequence in sequenceElements {
            let newNode = MediaOverlayNode()

            newNode.role.append("section")
            newNode.text = sequence.attributes["epub:textref"]
            parseParameters(in: sequence, withParent: newNode)
            parseSequences(in: sequence, withParent: newNode)

            // TO Translate
//            baseHref := strings.Split(moc.Text, "#")[0]
//            baseHrefParent := strings.Split(href, "#")[0]
//            if baseHref == baseHrefParent {
//                *mo = append(*mo, moc)
//            } else {
//                link := findLinKByHref(publication, baseHref)
//                link.MediaOverlays = append(link.MediaOverlays, moc)
//                if link.Properties == nil {
//                    link.Properties = &models.Properties{MediaOverlay: mediaOverlayURL + link.Href}
//                } else {
//                    link.Properties.MediaOverlay = mediaOverlayURL + link.Href
//                }
//            }
        }
    }

    /// Converts a smile time string into seconds String.
    ///
    /// - Parameter time: The smile time String.
    /// - Returns: The converted value in Seconds as String.
    fileprivate func smilTimeToSeconds(_ time: String) -> String {
        let timeFormat: SmilTimeFormat

        if time.contains("h") {
            timeFormat = .hour
        } else if time.contains("s") {
            timeFormat = .second
        } else if time.contains("ms") {
            timeFormat = .milisecond
        } else {
            let timeArity = time.components(separatedBy: ":").count

            guard let format = SmilTimeFormat(rawValue: timeArity) else {
                return ""
            }
            timeFormat = format
        }
        return timeFormat.convertToseconds(smilTime: time)
    }

    /// Parse the <audio> XML element, children of <par> elements.
    ///
    /// - Parameter audioElement: The audio XML element.
    /// - Returns: The formated string representing the data.
    fileprivate func parse(audioElement: AEXMLElement) -> String? {
        guard var audio = audioElement.attributes["src"],
            let clipBegin = audioElement.attributes["clipBegin"],
            let clipEnd = audioElement.attributes["clipEnd"] else
        {
            return nil
        }
        audio += "#t="
        audio += smilTimeToSeconds(clipBegin)
        audio += ","
        audio += smilTimeToSeconds(clipEnd)
        return audio
    }
}

/// Describe the differents time string format of the smile tags.
///
/// - splitMonadic: Handle `SS` format.
/// - splitDyadic//MM/SS: Handles `MM/SS` format.
/// - splitTriadic//HH:MM:SS: Handles `HH:MM:SS` format.
/// - milisecond: Handles `MM"ms"` format.
/// - second: Handles `SS"s" || SS.MM"s"` format
/// - hour: Handles `HH"h" || HH.MM"h"` format.
fileprivate enum SmilTimeFormat: Int {
    case splitMonadic = 1
    case splitDyadic
    case splitTriadic
    case milisecond
    case second
    case hour
}

fileprivate extension SmilTimeFormat {

    /// Return the seconds double value from a possible SS.MS format.
    ///
    /// - Parameter seconds: The seconds String.
    /// - Returns: The translated Double value.
    fileprivate func parseSeconds(_ time: String) -> Double {
        let secMilsec = time.components(separatedBy: ".")
        var seconds = 0.0

        if secMilsec.count == 2 {
            seconds = Double(secMilsec[0]) ?? 0.0
            seconds += (Double(secMilsec[1]) ?? 0.0) / 1000.0
        } else {
            seconds = Double(time) ?? 0.0
        }
        return seconds
    }

    /// Will confort the `smileTime` to the equivalent in seconds given it's
    /// type.
    ///
    /// - Parameter time: The `smilTime` `String`.
    /// - Returns: The converted value in seconds.
    func convertToseconds(smilTime time: String) -> String {
        var seconds = 0.0

        switch self {
        case .milisecond:
            let ms = Double(time.replacingOccurrences(of: "ms", with: ""))
            seconds = (ms ?? 0) / 1000.0
        case .second:
            seconds = Double(time.replacingOccurrences(of: "s", with: "")) ?? 0
        case .hour:
            let hourMin = time.replacingOccurrences(of: "h", with: "").components(separatedBy: ".")
            let hoursToSeconds = (Double(hourMin[0]) ?? 0) * 3600.0
            let minutesToSeconds = (Double(hourMin[1]) ?? 0) * 0.6 * 60.0

            seconds = hoursToSeconds + minutesToSeconds
        case .splitMonadic:
            return time
        case .splitDyadic:
            let minSec = time.components(separatedBy: ":")

            // Min
            seconds += (Double(minSec[0]) ?? 0.0) * 60
            // Sec
            seconds += parseSeconds(minSec[1])
        case .splitTriadic:
            let hourMinSec = time.components(separatedBy: ":")

            // Hour
            seconds += (Double(hourMinSec[0]) ?? 0.0) * 3600.0
            // Min
            seconds += (Double(hourMinSec[1]) ?? 0.0) * 60
            // Sec
            seconds += parseSeconds(hourMinSec[2])
        }
        return String(seconds)
    }
}













