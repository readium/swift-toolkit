//
//  ZIP.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum ZIPError: Error {
    /// The provided password was incorrect.
    case invalidPassword
    /// Impossible to open the given ZIP archive.
    case openFailed
    /// Impossible to modify the ZIP archive.
    case updateFailed
}

/// Represents an entry in a ZIP archive.
public protocol ZIPEntry {
    
    /// Absolute path to the entry in the archive, starting with /.
    var path: String { get }
    
    /// Whether this entry is a directory, instead of a file.
    var isDirectory: Bool { get }
    
    /// Uncompressed data length.
    /// Returns 0 if the entry is a directory.
    var length: UInt64 { get }
    
    /// Compressed data length.
    /// Returns 0 if the entry is a directory.
    var compressedLength: UInt64 { get }
    
    /// Reads the content of this entry, if it's a file.
    func read() -> Data?
    
}

/// Represents an immutable ZIP archive.
public protocol ZIPArchive {
    
    /// Creates a ZIP archive from a file URL.
    /// 
    /// - Throws: `ZIPError.openFailed` if the given `file` can't be opened.
    /// - Throws: `ZIPError.invalidPassword` if the provided `password` is wrong.
    init(file: URL, password: String?) throws
    
    /// List of all the archived entry paths.
    /// Directory entries are suffixed with /.
    var paths: [String] { get }
    
    /// Gets the entry at the given `path`.
    func entry(at path: String) -> ZIPEntry?

}

public extension ZIPArchive {
    
    /// Creates a ZIP archive from a file URL.
    init(file: URL) throws {
        try self.init(file: file, password: nil)
    }
    
}

/// A ZIP archive which can modify its entries.
public protocol MutableZIPArchive: ZIPArchive {
    
    /// Removes the entry at the given path.
    func removeEntry(at path: String) throws
    
    /// Adds a file entry to the ZIP archive.
    /// If the entry already exists, it is replaced.
    ///
    /// - Parameters:
    ///   - path: Absolute entry path, starting with /
    ///   - data: Entry data to be added.
    ///   - deflated: If true, the entry will be compressed in the archive.
    func addFile(at path: String, data: Data, deflated: Bool) throws
    
    /// Adds a directory entry to the ZIP archive.
    /// If the entry already exists, it is replaced.
    func addDirectory(at path: String) throws
    
}
