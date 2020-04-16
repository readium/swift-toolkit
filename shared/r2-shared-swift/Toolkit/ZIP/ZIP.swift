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

/// Holds a ZIP entry's metadata.
public struct ZIPEntry: Equatable {
    
    /// Absolute path to the entry in the archive.
    let path: String
    
    /// Whether this entry is a directory, instead of a file.
    let isDirectory: Bool
    
    /// Uncompressed data length.
    /// Returns 0 if the entry is a directory.
    let length: Int
    
    /// Compressed data length.
    /// Returns 0 if the entry is a directory.
    let compressedLength: Int

}

/// Represents an immutable ZIP archive.
public protocol ZIPArchive {
    
    /// Creates a ZIP archive from a file URL.
    /// 
    /// - Throws: `ZIPError.openFailed` if the given `file` can't be opened.
    /// - Throws: `ZIPError.invalidPassword` if the provided `password` is wrong.
    init(file: URL, password: String?) throws
    
    /// List of all the archived entries.
    var entries: [ZIPEntry] { get }
    
    /// Gets the entry at the given `path`.
    func entry(at path: String) -> ZIPEntry?
    
    /// Reads the whole content of the entry at the given `path`, if it's a file.
    func read(at path: String) -> Data?
    
    /// Reads a range of the content of this entry, if it's a file.
    func read(at path: String, range: Range<Int>) -> Data?

}

public extension ZIPArchive {
    
    /// Creates a ZIP archive from a file URL.
    init(file: URL) throws {
        try self.init(file: file, password: nil)
    }
    
}

/// A ZIP archive which can modify its entries.
public protocol MutableZIPArchive: ZIPArchive {

    /// Replaces (or adds) a file entry in the ZIP archive.
    ///
    /// - Parameters:
    ///   - path: Entry path.
    ///   - data: New entry data.
    ///   - deflated: If true, the entry will be compressed in the archive.
    func replace(at path: String, with data: Data, deflated: Bool) throws

}
