//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@available(*, unavailable)
public enum ArchiveError: Error {
    /// The provided password was incorrect.
    case invalidPassword(archive: String)
    /// Impossible to open the given archive.
    case openFailed(archive: String, cause: Error?)
    /// The entry could not be found in the archive.
    case entryNotFound(entry: ArchivePath, archive: String)
    /// Impossible to read the given entry.
    case readFailed(entry: ArchivePath, archive: String, cause: Error?)
}

@available(*, unavailable)
public typealias ArchiveResult<Success> = Result<Success, ArchiveError>

@available(*, unavailable)
public typealias ArchivePath = String

@available(*, unavailable, renamed: "Container")
public protocol Archive {
    var entries: [ArchiveEntry] { get }
    func entry(at path: ArchivePath) -> ArchiveEntry?
    func readEntry(at path: ArchivePath) -> ArchiveEntryReader?
    func close()
}

@available(*, unavailable)
public struct ArchiveEntry: Equatable {
    /// Absolute path to the entry in the archive. It MUST start with /.
    let path: ArchivePath
    /// Uncompressed data length.
    let length: UInt64
    /// Compressed data length, or nil if the entry is not compressed.
    let compressedLength: UInt64?
}

@available(*, unavailable)
public protocol ArchiveEntryReader {
    /// Direct file to the entry, when available. For example when the archive is exploded on the file system.
    ///
    /// This is meant to be used as an optimization for consumers which can't work efficiently with streams. However,
    /// the file is not guaranteed to be found, for example if the archive is a ZIP. Therefore, consumers should always
    /// fallback on regular stream reading, using `read()`.
    var file: FileURL? { get }

    /// Reads the content of this entry.
    ///
    /// When `range` is nil, the whole content is returned. Out-of-range indexes are clamped to the available length
    /// automatically.
    func read(range: Range<UInt64>?) -> ArchiveResult<Data>

    /// Closes any pending resources for this entry.
    func close()
}

@available(*, unavailable, renamed: "ArchiveOpener")
public protocol ArchiveFactory {
    /// Opens an archive from a local file path.
    func open(file: FileURL, password: String?) -> ArchiveResult<Archive>
}

@available(*, unavailable, renamed: "DefaultArchiveOpener")
public class DefaultArchiveFactory {}
