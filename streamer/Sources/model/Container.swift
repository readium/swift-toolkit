//
//  Container.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 14/12/2016.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import AEXML

/// Container protocol associated errors.
///
/// - streamInitFailed: The inputStream initialisation failed.
/// - fileNotFound: The file could not be found.
/// - fileError: An error occured while accessing the file attributes.
/// - missingFile: The file at the given path couldn't not be found.
/// - xmlParse: An error occured while parsing XML (See underlyingError for more infos).
/// - missingLink: The given `Link` ressource couldn't be found in the container.
public enum ContainerError: Error {
    case streamInitFailed
    case fileNotFound
    case fileError
    case missingFile(path: String)
    case xmlParse(underlyingError: Error)
    case missingLink(title: String?)

    public var localizedDescription: String {
        switch self {
        case .streamInitFailed:
            return "Stream initialization failed."
        case .fileNotFound:
            return "The file couldn't be found."
        case .fileError:
            return "An error occured while accessing the file attributes."
        case .missingFile(let path):
            return "The file at \(path) is missing from the archive."
        case .xmlParse(let underlyingError):
            return "Error while parsing XML: \(underlyingError.localizedDescription)"
        case .missingLink(let title):
            return "The link, titled \(title ?? "missing"), couldn't be found in the container."
        }
    }
}

/// Provide methods for accessing raw data from container's files.
public protocol Container {

    /// See `RootFile`.
    var rootFile: RootFile { get set }
    
    /// Last modification date of the container.
    var modificationDate: Date { get }

    /// The DRM protecting resources (some) in the container.
    var drm: DRM? { get set }

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

public extension Container {
    
    /// The default implementation reads the modification date from the root file.
    /// FIXME: This is needed because the PublicationServer is returning the Publications sorted by date, so that the most recent are visible at the top in the library. But this is UX behavior and should be refactored in the test app's LibraryViewController, instead of exposing it here.
    var modificationDate: Date {
        let url = NSURL(fileURLWithPath: rootFile.rootPath)
        var modificationDate : AnyObject?
        try? url.getResourceValue(&modificationDate, forKey: .contentModificationDateKey)
        print("\(rootFile.rootPath) - \(modificationDate as! Date)")
        return (modificationDate as? Date) ?? Date()
    }
    
}
