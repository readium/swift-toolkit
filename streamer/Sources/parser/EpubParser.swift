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
    /// (see OPF_2.0.1_draft 1.3.2).
    static let defaultEpubVersion = 1.2
    /// Path of the EPUB's container.xml file.
    static let containerDotXmlPath = "META-INF/container.xml"
    /// Path of the EPUB's ecryption file.
    static let encryptionDotXmlPath = "META-INF/encryption.xml"
    /// Epub mime-type.
    static let mimetype = "application/epub+zip"
    /// http://www.idpf.org/oebps/ (Legacy)
    static let mimetypeOEBPS = "application/oebps-package+xml"
    /// Media Overlays URL.
    static let mediaOverlayURL = "media-overlay?resource="
    // PageSpread
    static let autoMeta = "auto"
    static let noneMeta = "none"
    static let reflowableMeta = "reflowable"
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
    /// An XML elemen cannot be found.
    case missingElement(message: String)
}

extension EpubParser: Loggable {}

/// An EPUB container parser that extracts the information from the relevant
/// files and builds a `Publication` instance with it.
public class EpubParser: PublicationParser {
    internal let opfp: OPFParser!
    internal let ndp: NavigationDocumentParser!
    internal let ncxp: NCXParser!
    internal let encp: EncryptionParser!

    // TODO: multiple renditions

    // MARK: - Public methods

    public init() {
        opfp = OPFParser()
        ndp = NavigationDocumentParser()
        ncxp = NCXParser()
        encp = EncryptionParser()
    }

    /// Parses the EPUB (file/directory) at `fileAtPath` and generate
    /// `Publication` and `Container`.
    ///
    /// - Parameter fileAtPath: The path to the epub file.
    /// - Returns: the resulting publication.
    /// - Throws: `EpubParserError.wrongMimeType`,
    ///           `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingFile`
    public func parse(fileAtPath path: String) throws -> PubBox {
        // Generate the `Container` for `fileAtPath`
        var container = try generateContainerFrom(fileAtPath: path)

        // Retrieve mimetype data from container,
        // + convert data to string,
        // + check if mimetype's valid.
        guard let mimeTypeData = try? container.data(relativePath: "mimetype"),
            let mimetype = String(data: mimeTypeData, encoding: .ascii),
            mimetype == EpubConstant.mimetype else {
                throw EpubParserError.wrongMimeType
        }
        container.rootFile.mimetype = mimetype
        // Retrieve container.xml data from the Container
        guard let data = try? container.data(relativePath: EpubConstant.containerDotXmlPath) else {
            throw EpubParserError.missingFile(path: EpubConstant.containerDotXmlPath)
        }
        // Parse the container.xml Data and fill the ContainerMetadata objectof the container
        container.rootFile.rootFilePath =  try getRootFilePath(from: data)
        // Get the package.opf XML document from the container.
        let document = try container.xmlDocument(forFileAtRelativePath: container.rootFile.rootFilePath)
        let epubVersion = getEpubVersion(from: document)
        // Parse OPF file (Metadata, Spine, Resource) and return the Publication.
        var publication = try opfp.parseOPF(from: document, with: container, and: epubVersion)
        // Parse the META-INF/Encryption.xml.
        parseEncryption(from: container, to: &publication)
        // Parse Navigation Document.
        parseNavigationDocument(from: container, to: &publication)
        // Parse the NCX Document (if any).
        parseNcxDocument(from: container, to: &publication)
        return (publication, container)
    }

    // MARK: - Internal Methods.

    /// Parse the Encryption.xml EPUB file. It contains the informationg about
    /// encrypted resources and how to decrypt them
    ///
    /// - Parameters:
    ///   - container: The EPUB Container.
    ///   - publication: The Publication.
    /// - Throws: 
    internal func parseEncryption(from container: EpubContainer, to publication: inout Publication) {
        // Check if there is an encryption file.
        guard let document = try? container.xmlDocument(forFileAtRelativePath: EpubConstant.encryptionDotXmlPath) else {
            log(level: .warning, "The file “encryption.xml” couldn’t be opened")
            return
        }
        guard let encryptedDataElements = document["encryption"]["EncryptedData"].all else {
            log(level: .info, "No <EncryptedData> elements")
            return
        }
        // Loop through <EncryptedData> elements..
        for encryptedDataElement in encryptedDataElements {
            var encryption = Encryption()

            encryption.algorithm = encryptedDataElement["EncryptionMethod"].attributes["Algorithm"]
            // TODO: LCP encryption. Profile/Scheme if lcp.id != nil
            encp.parseEncryptionProperties(from: encryptedDataElement, to: &encryption)
            encp.add(encryption: encryption, toLinkInPublication: &publication,
                     encryptedDataElement)
        }
        // TODO: LCP
    }

    /// Attempt to fill `Publication.tableOfContent`/`.landmarks`/`.pageList`/
    ///                              `.listOfIllustration`/`.listOftables`
    /// using the navigation document.
    ///
    /// - Parameters:
    ///   - container: The Epub container.
    ///   - publication: The Epub publication.
    internal func parseNavigationDocument(from container: EpubContainer, to publication: inout Publication) {
        // Get the link in the spine pointing to the Navigation Document.
        guard let navLink = publication.link(withRel: "contents"),
            let navDocument = try? container.xmlDocument(forRessourceReferencedByLink: navLink) else {
                return
        }
        let newTableOfContentsItems = ndp.tableOfContent(fromNavigationDocument: navDocument)
        let newLandmarksItems = ndp.landmarks(fromNavigationDocument: navDocument)
        let newListOfAudiofiles = ndp.listOfAudiofiles(fromNavigationDocument: navDocument)
        let newListOfIllustrations = ndp.listOfIllustrations(fromNavigationDocument: navDocument)
        let newListOfTables = ndp.listOfTables(fromNavigationDocument: navDocument)
        let newListOfVideos = ndp.listOfVideos(fromNavigationDocument: navDocument)
        let newPageListItems = ndp.pageList(fromNavigationDocument: navDocument)

        publication.tableOfContents.append(contentsOf:  newTableOfContentsItems)
        publication.landmarks.append(contentsOf: newLandmarksItems)
        publication.listOfAudioFiles.append(contentsOf: newListOfAudiofiles)
        publication.listOfIllustrations.append(contentsOf: newListOfIllustrations)
        publication.listOfTables.append(contentsOf: newListOfTables)
        publication.listOfVideos.append(contentsOf: newListOfVideos)
        publication.pageList.append(contentsOf: newPageListItems)
    }

    /// Attempt to fill `Publication.tableOfContent`/`.pageList` using the NCX
    /// document. Will only modify the Publication if it has not be filled
    /// previously (using the Navigation Document).
    ///
    /// - Parameters:
    ///   - container: The Epub container.
    ///   - publication: The Epub publication.
    internal func parseNcxDocument(from container: EpubContainer, to publication: inout Publication) {
        // Get the link in the spine pointing to the NCX document.
        guard let ncxLink = publication.resources.first(where: { $0.typeLink == "application/x-dtbncx+xml" }),
            let ncxDocument = try? container.xmlDocument(forRessourceReferencedByLink: ncxLink) else {
                return
        }
        if publication.tableOfContents.isEmpty {
            let newTableOfContentItems = ncxp.tableOfContents(fromNcxDocument: ncxDocument)

            publication.tableOfContents.append(contentsOf: newTableOfContentItems)
        }
        if publication.pageList.isEmpty {
            let newPageListItems = ncxp.pageList(fromNcxDocument: ncxDocument)

            publication.pageList.append(contentsOf: newPageListItems)
        }
    }

    // MARK: - Fileprivate Methods.

    /// Parses the container.xml file and retrieve the relative path to the opf
    /// file(rootFilePath) (the default one for now, not handling multiple
    /// renditions).
    ///
    /// - Parameter data: The containerDotXml `Data` representation.
    /// - Throws: `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingElement`.
    fileprivate func getRootFilePath(from data: Data) throws -> String {
        let containerDotXml: AEXMLDocument

        do {
            containerDotXml = try AEXMLDocument(xml: data)
        } catch {
            throw EpubParserError.xmlParse(underlyingError: error)
        }
        // Look for the `<roofile>` element.
        let rootFileElement = containerDotXml.root["rootfiles"]["rootfile"]
        // Get the path of the OPF file, relative to the metadata.rootPath.
        guard let opfFilePath = getRelativePathToOPF(from: rootFileElement) else {
            throw EpubParserError.missingElement(message: "Missing rootfile in `container.xml`.")
        }
        return opfFilePath
    }

    /// Retrieves the OPF file path from the fisrt <rootfile> element.
    ///
    /// - Parameter containerXml: The XML container instance.
    /// - Returns: The OPF file path.
    /// - Throws: `EpubParserError.missingElement`.
    fileprivate func getRelativePathToOPF(from rootFileElement: AEXMLElement) -> String? {
        guard let fullPath = rootFileElement.attributes["full-path"] else {
            return nil
        }
        return fullPath
    }

    /// Retrieve the EPUB version from the package.opf XML document else set it 
    /// to the default value `EpubConstant.defaultEpubVersion`.
    ///
    /// - Parameter containerXml: The XML container instance.
    /// - Returns: The OPF file path.
    fileprivate func getEpubVersion(from document: AEXMLDocument) -> Double {
        let version: Double

        if let versionAttribute = document.root.attributes["version"],
            let versionNumber = Double(versionAttribute)
        {
            version = versionNumber
        } else {
            version = EpubConstant.defaultEpubVersion
        }
        return version
    }

    /// Generate a Container instance for the file at `fileAtPath`. It handles
    /// 2 cases, epub files and unwrapped epub directories.
    ///
    /// - Parameter path: The absolute path of the file.
    /// - Returns: The generated Container.
    /// - Throws: `EpubParserError.missingFile`.
    fileprivate func generateContainerFrom(fileAtPath path: String) throws -> EpubContainer {
        var isDirectory: ObjCBool = false
        var container: EpubContainer?

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw EpubParserError.missingFile(path: path)
        }
        if isDirectory.boolValue {
            container = ContainerEpubDirectory(directory: path)
        } else {
            container = ContainerEpub(path: path)
        }
        guard let containerUnwrapped = container else {
            throw EpubParserError.missingFile(path: path)
        }
        return containerUnwrapped
    }
}
