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

    /// Takes the path to one of the ressources and returns an XML document.
    ///
    /// - Parameters:
    ///   - path: The path to the ressource inside the container.
    /// - Returns: The XML document Object generated.
    /// - Throws: EpubParserError.missingFile(),
    ///           EpubParserError.xmlParse().
    func xmlDocumentForFile(atPath path: String) throws -> AEXMLDocument
}

extension Container {

    public func xmlDocumentForFile(atPath path: String) throws -> AEXMLDocument {
        // The 'to be built' XML Document
        var document: AEXMLDocument

        // Get `Data` from the Container/OPFFile
        guard let data = try? data(relativePath: path) else {
            throw EpubParserError.missingFile(path: path)
        }
        // Transforms `Data` into an AEXML Document object
        do {
            document = try AEXMLDocument(xml: data)
        } catch {
            throw EpubParserError.xmlParse(underlyingError: error)
        }
        return document
    }

}

