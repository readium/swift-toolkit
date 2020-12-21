//
//  Archive.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum ArchiveError: Error {
    /// The provided password was incorrect.
    case invalidPassword
    /// Impossible to open the given archive.
    case openFailed
    /// Impossible to modify the archive.
    case updateFailed
    /// The entry could not be found in the archive.
    case entryNotFound
}

/// Holds an archive entry's metadata.
public struct ArchiveEntry: Equatable {
    
    /// Absolute path to the entry in the archive.
    let path: String
    
    /// Uncompressed data length.
    let length: UInt64?
    
    /// Whether the entry is compressed.
    let isCompressed: Bool
    
    /// Compressed data length, or nil if the entry is not compressed.
    let compressedLength: UInt64?

}

/// Represents an immutable archive, such as a ZIP file or an exploded directory.
public protocol Archive {
    
    /// Creates an archive from a local file URL.
    /// 
    /// - Throws: `ArchiveError.openFailed` if the given `file` can't be opened.
    /// - Throws: `ArchiveError.invalidPassword` if the provided `password` is wrong.
    init(url: URL, password: String?) throws
    
    /// List of all the archived entries.
    var entries: [ArchiveEntry] { get }
    
    /// Gets the entry at the given `path`
    ///
    /// - Throws: `ArchiveError.entryNotFound` if the entry can't be located.
    func entry(at path: String) throws -> ArchiveEntry
    
    /// Reads the whole content of the entry at the given `path`.
    func read(at path: String) -> Data?
    
    /// Reads a range of the content of this entry.
    func read(at path: String, range: Range<UInt64>) -> Data?
    
    /// Direct file to the entry at given `path`, when available.
    /// For example when the archive is exploded on the file system.
    ///
    /// This is meant to be used as an optimization for consumers which can't work efficiently with
    /// streams. However, the file is not guaranteed to be found, for example if the archive is a
    /// ZIP. Therefore, consumers should always fallback on regular stream reading, using `read()`.
    func file(at path: String) -> URL?
    
    /// Closes the archive.
    func close()

}

public extension Archive {
    
    /// Creates an archive from a local file URL.
    init(url: URL) throws {
        try self.init(url: url, password: nil)
    }
    
    func file(at path: String) -> URL? {
        return nil
    }
    
}

/// An archive which can modify its entries.
protocol MutableArchive: Archive {

    /// Replaces (or adds) a file entry in the archive.
    ///
    /// - Parameters:
    ///   - path: Entry path.
    ///   - data: New entry data.
    ///   - deflated: If true, the entry will be compressed in the archive.
    func replace(at path: String, with data: Data, deflated: Bool) throws

}

public protocol ArchiveFactory {
    
    /// Opens an archive from a local file path.
    func open(url: URL, password: String?) throws -> Archive
    
}

public class DefaultArchiveFactory: ArchiveFactory, Loggable {
    
    public init() {}
    
    public func open(url: URL, password: String?) throws -> Archive {
        warnIfMainThread()
        do {
            return try ExplodedArchive(url: url, password: password)
        } catch {
            return try MinizipArchive(url: url, password: password)
        }
    }
    
}
