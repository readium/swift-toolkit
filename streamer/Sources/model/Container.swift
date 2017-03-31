//
//  Container.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import AEXML

/// Container Protocol's Errors.
///
/// - streamInitFailed:
/// - fileNotFound: File couldn't be found.
/// - fileError:
public enum ContainerError: Error {
    case streamInitFailed
    case fileNotFound
    case fileError

    // Extenssion related.
    /// The file at the given path couldn't not be found.
    case missingFile(path: String)
    /// An error occured during the XML parsing.
    case xmlParse(underlyingError: Error)
    /// The given link is missing from the
    case missingLink(title: String?)

}

/// Container protocol, for accessing raw data from container's files.
public protocol Container {

    /// Meta-informations about the Container. See ContainerMetadata struct for
    /// more details.
    var rootFile: RootFile { get set }

    /// Get the raw (possibly encrypted) data of an asset in the container
    ///
    /// - Parameter relativePath: The relative path to the asset.
    /// - Returns: The data of the asset.
    /// - Throws: An error from EpubDataContainerError enum depending of the
    ///           overriding method's implementation.
    func data(relativePath: String) throws -> Data

    /// Get the size of an asset in the container.
    ///
    /// - Parameter relativePath: The relative path to the asset.
    /// - Returns: The size of the asset.
    /// - Throws: An error from EpubDataContainerError enum depending of the
    ///           overrding method's implementation.
    func dataLength(relativePath: String) throws -> UInt64

    /// Get an seekable input stream with the bytes of the asset in the container.
    ///
    /// - Parameter relativePath: The relative path to the asset.
    /// - Returns: A seekable input stream.
    /// - Throws: An error from EpubDataContainerError enum depending of the
    ///           overrding method's implementation.
    func dataInputStream(relativePath: String) throws -> SeekableInputStream
}

/// Specializing the Container for Epubs.
protocol EpubContainer: Container {
    /// Return a XML document representing the file at path.
    ///
    /// - Parameter path: The 'container relative' path to the ressource.
    /// - Returns: The generated document.
    /// - Throws: `ContainerError.missingFile`,
    ///           `ContainerError.xmlParse`.
    func xmlDocument(ForFileAtRelativePath path: String) throws -> AEXMLDocument

    /// Return a XML Document representing the file referenced by `link`.
    ///
    /// - Parameters:
    ///   - link: The `Link` to the ressource from the manifest.
    /// - Returns: The XML Document.
    /// - Throws: `ContainerError.missingFile`,
    ///           `ContainerError.xmlParse`.
    func xmlDocument(forRessourceReferencedByLink link: Link?) throws -> AEXMLDocument
}
/// Default Implementation
extension EpubContainer {

    /// Return a XML document representing the file at path.
    ///
    /// - Parameter path: The 'container relative' path to the ressource.
    /// - Returns: The generated document.
    /// - Throws: `ContainerError.missingFile`,
    ///           `ContainerError.xmlParse`.
    public func xmlDocument(ForFileAtRelativePath path: String) throws -> AEXMLDocument {
        // The 'to be built' XML Document
        var document: AEXMLDocument

        // Get `Data` from the Container/OPFFile
        guard let data = try? data(relativePath: path) else {
            throw ContainerError.missingFile(path: path)
        }
        // Transforms `Data` into an AEXML Document object
        do {
            document = try AEXMLDocument(xml: data)
        } catch {
            throw ContainerError.xmlParse(underlyingError: error)
        }
        return document
    }

    /// Return a XML Document representing the file referenced by `link`.
    ///
    /// - Parameters:
    ///   - link: The `Link` to the ressource from the manifest.
    ///   - container: The epub container.
    /// - Returns: The XML Document.
    public func xmlDocument(forRessourceReferencedByLink link: Link?) throws -> AEXMLDocument {
        // The `to be generated` document.
        var document: AEXMLDocument
        // Path to the rootDir
        let rootDirPath = rootFile.rootFilePath.deletingLastPathComponent()

        // Get the ressource file the link's pointing to, contained in the href.
        guard let href = link?.href else {
            throw ContainerError.missingLink(title: link?.title)
        }
        // Generate the relative path to the ressource pointed to by `link`.
        let relativeFilePath = rootDirPath.appending(pathComponent: href)
        // Generate the document for the ressource at relativeFilePath.
        do {
            document = try xmlDocument(ForFileAtRelativePath: relativeFilePath)
        } catch {
            throw ContainerError.xmlParse(underlyingError: error)
        }
        return document
    }

}

/// Specializing the container for Directories.
protocol DirectoryContainer: Container {}
/// Default implementation.
extension DirectoryContainer {
    public func data(relativePath: String) throws -> Data {
        let fullPath = generateFullPath(with: relativePath)

        return try Data(contentsOf: URL(fileURLWithPath: fullPath), options: [.mappedIfSafe])
    }

    public func dataLength(relativePath: String) throws -> UInt64 {
        let fullPath = generateFullPath(with: relativePath)

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath) else {
            throw ContainerError.fileError
        }
        guard let fileSize = attributes[FileAttributeKey.size] as? UInt64 else {
            throw ContainerError.fileError
        }
        return fileSize
    }

    public func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        let fullPath = generateFullPath(with: relativePath)

        guard let inputStream = FileInputStream(fileAtPath: fullPath) else {
            throw ContainerError.streamInitFailed
        }
        return inputStream
    }

    // MARK: - Internal methods

    /// Generate an absolute path to a ressource from a given relative path.
    ///
    /// - Parameter relativePath: The 'directory-relative' path to the ressource.
    /// - Returns: The absolute path to the ressource
    internal func generateFullPath(with relativePath: String) -> String {
        let fullPath = rootFile.rootPath.appending(pathComponent: relativePath)

        return fullPath
    }
}

/// Specializing the Container for Arhived files.
protocol ZipArchiveContainer: Container {
    /// The zip archive object containing the Epub.
    var zipArchive: ZipArchive { get set }
}
/// Default implementation.
extension ZipArchiveContainer {

    public func data(relativePath: String) throws -> Data {
        return try zipArchive.readData(path: relativePath)
    }

    // Implements Container protocol
    public func dataLength(relativePath: String) throws -> UInt64 {
        return try zipArchive.fileSize(path: relativePath)
    }

    // Implements Container protocol
    public func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        // let inputStream = ZipInputStream(zipArchive: zipArchive, path: relativePath)
        guard let inputStream = ZipInputStream(zipFilePath: rootFile.rootPath,
                                               path: relativePath) else {
                                                throw ContainerError.streamInitFailed
        }
        return inputStream
    }
}
