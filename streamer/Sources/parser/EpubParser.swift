//
//  RDEpubParser.swift
//  R2Streamer
//
//  Created by Olivier Körner on 08/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import AEXML

/// Epub related constants.
public struct EPUBConstant {

    /// Default EPUB Version value, used when no version hes been specified.
    /// (see OPF_2.0.1_draft 1.3.2)
    static let defaultEpubVersion = 1.2

    /// Epub+zip mime-type
    static let mimetype = "application/epub+zip"
}

/// Errors thrown during the parsing of the EPUB
///
/// - wrongMimeType: The mimetype file is missing or its content differs from
///                 `application/epub+zip`.
/// - missingFile: A file is missing from the container.
/// - xmlParse: An XML parsing error occurred.
/// - missingElement: An XML element is missing.
public enum EpubParserError: Error {

    /// MimeType "application/epub+zip" expected.
    case wrongMimeType

    /// A file is missing from the container at relative path **path**.
    case missingFile(path: String)

    /// An XML parsing error occurred, **underlyingError** thrown by the parser.
    case xmlParse(underlyingError: Error)

    case missingElement(message: String)
}

/// An EPUB container parser that extracts the information from the relevant
/// files and builds a `Publication` instance with it.
///
/// - It checks for a `mimetype` file with the proper contents.
/// - It parses `container.xml` to look for the default rendition.
/// - It parses the OPF file of the default rendition for the metadata,
///   the assets and the spine.
open class EpubParser {

    /// The EPUB container to parse.
    public var container: Container

    /// The EPUB specification version to which the publication conforms.
    internal var epubVersion: Double!

    /// The OPF parser object.
    internal var opfParser: OPFParser!

    /// The path to the default package document (OPF) to parse.
    internal var rootFilePath: String!

    // TODO: multiple renditions
    // TODO: media overlays
    // TODO: TOC, LOI, etc.
    // TODO: encryption info

    // MARK: - Public methods

    /// The `EpubParser` is initialized with a `Container`, through which it
    /// can access to the raw data of the files in the EPUB container.
    ///
    /// - Parameter container: A `Container` instance.
    /// - Throws: `EpubParserError.wrongMimeType`,
    ///           `EpubParserError.missingFile`,
    ///           `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingElement`
    required public init(container: Container) throws {
        let mimetype: String?

        self.container = container
        guard let mimeTypeData = try? container.data(relativePath: "mimetype") else {
            throw EpubParserError.wrongMimeType
        }
        mimetype = String(data: mimeTypeData, encoding: .ascii)
        guard mimetype == EPUBConstant.mimetype else {
            throw EpubParserError.wrongMimeType
        }
        try parseContainer()
        self.opfParser = OPFParser(for: self.container, with: epubVersion)
    }

    /// Parses the EPUB container files and builds a `Publication` representation.
    ///
    /// - Returns: the resulting publication.
    /// - Throws: `EpubParserError.wrongMimeType`,
    ///           `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingFile`
    public func parse() throws -> Publication {
        let publication = try opfParser.parseOPF(at: rootFilePath)

        return publication
    }

    // MARK: - Internal methods.

    /// Parses the container.xml file of the container.
    /// It extracts the root file (the default one for now, not handling
    /// multiple renditions).
    ///
    /// - Throws: `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingFile`,
    ///           `EpubParserError.missingElement`.
    internal func parseContainer() throws {
        let containerPath = "META-INF/container.xml"
        let containerXml: AEXMLDocument
        let rootFileElement: AEXMLElement

        guard let containerData = try? container.data(relativePath: containerPath) else {
            throw EpubParserError.missingFile(path: containerPath)
        }
        do {
            containerXml = try AEXMLDocument(xml: containerData)
        } catch {
            throw EpubParserError.xmlParse(underlyingError: error)
        }
        // Look for the first `<roofile>` element
        rootFileElement = containerXml.root["rootfiles"]["rootfile"]

        rootFilePath = try getRootFilePath(from: rootFileElement)
        // Get the specifications version the EPUB conforms to
        // If not set in the container, it will be retrieved during OPF parsing
        if let version = rootFileElement.attributes["version"],
            let versionNumber = Double(version) {
            epubVersion = versionNumber
        } else {
            epubVersion = EPUBConstant.defaultEpubVersion
        }
    }


    /// Retrieves the OPF file path from the fisrt <rootfile> element.
    ///
    /// - Parameter containerXml: The XML container instance.
    /// - Returns: The OPF file path.
    /// - Throws: `EpubParserError.missingElement`.
    internal func getRootFilePath(from rootFileElement: AEXMLElement) throws -> String {
        guard let fullPath = rootFileElement.attributes["full-path"] else {
            throw EpubParserError.missingElement(message: "Missing rootfile element in container.xml")
        }
        return fullPath
    }
}
