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
public struct EpubConstant {

    /// Default EPUB Version value, used when no version hes been specified.
    /// (see OPF_2.0.1_draft 1.3.2)
    static let defaultEpubVersion = 1.2

    /// Path of the EPUB's container.xml file
    static let containerDotXmlPath = "META-INF/container.xml"

    /// Epub mime-type
    static let mimetypeEPUB = "application/epub+zip"

    /// http://www.idpf.org/oebps/
    static let mimetypeOEBPS = "application/oebps-package+xml" // TODO: support?
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
/// The container store the state information and is modified along the process.
///
/// - It checks for a `mimetype` file with the proper contents.
/// - It parses `container.xml` to look for the default rendition.
/// - It parses the OPF file of the default rendition for the metadata,
///   the assets and the spine.
open class EpubParser {

    /// The OPF parser object, used to parse the 'package.opf' file of the
    /// container.
    public var opfParser = OPFParser()

    // TODO: multiple renditions
    // TODO: media overlays
    // TODO: TOC, LOI, etc.
    // TODO: encryption info

    // MARK: - Public methods

    public init() {}

    /// Parses the EPUB Container and builds a `Publication`. Passed as inout
    /// as it also fill the Container Object metadata.
    ///
    /// - Parameter container: The Container containing the epub.
    /// - Returns: the resulting publication.
    /// - Throws: `EpubParserError.wrongMimeType`,
    ///           `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingFile`
    public func parse(container: inout Container) throws -> Publication {
        // Retrieve mimetype data from container, convert data to string,
        // then check if valid mimetype
        guard let mimeTypeData = try? container.data(relativePath: "mimetype"),
              let mimetype = String(data: mimeTypeData, encoding: .ascii),
              mimetype == EpubConstant.mimetypeEPUB else {
            throw EpubParserError.wrongMimeType
        }
        // Retrieve container.xml data from the Container
        guard let data = try? container.data(relativePath: EpubConstant.containerDotXmlPath) else {
            throw EpubParserError.missingFile(path: EpubConstant.containerDotXmlPath)
        }
        // Parse the container.xml Data and fill the ContainerMetadata object
        // of the container
        try parseContainerDotXml(from: data, to: &(container.metadata))
        // Parse the opf file and return the Publication.
        return try opfParser.parseOPF(from: &container)
    }

    // MARK: - Private methods.

    /// Parses the container.xml file and retrieve the relative path to the opf
    /// file (the default one for now, not handling multiple renditions).
    ///
    /// - Parameter data: The containerDotXml `Data` representation.
    /// - Throws: `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingFile`,
    ///           `EpubParserError.missingElement`.
    private func parseContainerDotXml(
        from data: Data,
        to metadata: inout ContainerMetadata) throws {
        let containerDotXml: AEXMLDocument
        let rootFileElement: AEXMLElement

        do {
            containerDotXml = try AEXMLDocument(xml: data)
        } catch {
            throw EpubParserError.xmlParse(underlyingError: error)
        }
        // Look for the first `<roofile>` element
        rootFileElement = containerDotXml.root["rootfiles"]["rootfile"]
        // Get the path of the OPF file, relative to the metadata.rootPath.
        guard let opfFilePath = getRelativePathToOPF(from: rootFileElement) else {
            throw EpubParserError.missingElement(message: "Missing rootfile in `container.xml`.")
        }
        metadata.rootFilePath = opfFilePath
    }

    /// Retrieves the OPF file path from the fisrt <rootfile> element.
    ///
    /// - Parameter containerXml: The XML container instance.
    /// - Returns: The OPF file path.
    /// - Throws: `EpubParserError.missingElement`.
    private func getRelativePathToOPF(from rootFileElement: AEXMLElement) -> String? {
        guard let fullPath = rootFileElement.attributes["full-path"] else {
            return nil
        }
        return fullPath
    }
}
