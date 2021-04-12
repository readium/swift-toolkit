//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum ArchiveError: Error {
    /// The provided password was incorrect.
    case invalidPassword(archive: URL)
    /// Impossible to open the given archive.
    case openFailed(archive: URL, cause: Error?)
    /// The entry could not be found in the archive.
    case entryNotFound(entry: ArchivePath, archive: URL)
    /// Impossible to read the given entry.
    case readFailed(entry: ArchivePath, archive: URL, cause: Error?)
}

public typealias ArchiveResult<Success> = Result<Success, ArchiveError>

/// Path of an entry relative to the root of the archive.
public typealias ArchivePath = String

/// Represents an immutable archive, such as a ZIP file or an exploded directory.
public protocol Archive {

    /// List of all the archived entries metadata.
    var entries: [ArchiveEntry] { get }

    /// Returns the metadata for the entry at given path.
    func entry(at path: ArchivePath) -> ArchiveEntry?

    /// Gets a reader for the entry at the given `path`, or nil if the entry doesn't exist.
    func readEntry(at path: ArchivePath) -> ArchiveEntryReader?

    /// Closes the archive.
    func close()

}

public extension Archive {

    func entry(at path: ArchivePath) -> ArchiveEntry? {
        entries.first { $0.path == path }
    }

}

/// Holds metadata about a single archive entry.
public struct ArchiveEntry: Equatable {
    /// Absolute path to the entry in the archive. It MUST starts with /.
    let path: ArchivePath
    /// Uncompressed data length.
    let length: UInt64
    /// Compressed data length, or nil if the entry is not compressed.
    let compressedLength: UInt64?
}

/// Provides access to an entry's content.
public protocol ArchiveEntryReader {

    /// Direct file to the entry, when available. For example when the archive is exploded on the file system.
    ///
    /// This is meant to be used as an optimization for consumers which can't work efficiently with streams. However,
    /// the file is not guaranteed to be found, for example if the archive is a ZIP. Therefore, consumers should always
    /// fallback on regular stream reading, using `read()`.
    var file: URL? { get }

    /// Reads the content of this entry.
    ///
    /// When `range` is nil, the whole content is returned. Out-of-range indexes are clamped to the available length
    /// automatically.
    func read(range: Range<UInt64>?) -> ArchiveResult<Data>

    /// Closes any pending resources for this entry.
    func close()

}

extension ArchiveEntryReader {

    public var file: URL? { nil }

    /// Reads the whole content of this entry.
    func read() -> ArchiveResult<Data> {
        return read(range: nil)
    }

}

public protocol ArchiveFactory {
    
    /// Opens an archive from a local file path.
    func open(url: URL, password: String?) -> ArchiveResult<Archive>
    
}

public class DefaultArchiveFactory: ArchiveFactory, Loggable {
    
    public init() {}

    public func open(url: URL, password: String?) -> ArchiveResult<Archive> {
        warnIfMainThread()
        return ExplodedArchive.make(url: url)
            .map { $0 as Archive}
            .catch { _ in MinizipArchive.make(url: url).map { $0 as Archive } }
    }
    
}
