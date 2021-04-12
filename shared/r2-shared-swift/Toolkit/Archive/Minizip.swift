//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Minizip

enum MinizipArchiveError: Error {
    case notAFileURL(URL)
    case fileNotReachable(URL)
    case notAValidZIP(URL)
    case entryAlreadyClosed(ArchivePath)
}

/// A ZIP `Archive` using the Minizip library.
final class MinizipArchive: Archive, Loggable {

    static func make(url: URL) -> ArchiveResult<MinizipArchive> {
        guard url.isFileURL else {
            return .failure(.openFailed(archive: url, cause: MinizipArchiveError.notAFileURL(url)))
        }
        guard (try? url.checkResourceIsReachable()) ?? false else {
            return .failure(.openFailed(archive: url, cause: MinizipArchiveError.fileNotReachable(url)))
        }
        guard let file = MinizipFile(url: url) else {
            return .failure(.openFailed(archive: url, cause: MinizipArchiveError.notAValidZIP(url)))
        }
        defer { try? file.close() }

        do {
            var entries: [ArchiveEntry] = []

            try file.goToFirstEntry()
            repeat {
                switch try file.entryMetadataAtCurrentOffset() {
                case let .file(path, length: length, compressedLength: compressedLength):
                    entries.append(ArchiveEntry(path: path.addingPrefix("/"), length: length, compressedLength: compressedLength))
                case .directory:
                    // Directories are ignored
                    break
                }
            } while try file.goToNextEntry()

            return .success(try Self(url: url, entries: entries))

        } catch {
            return .failure(.openFailed(archive: url, cause: error))
        }
    }

    let entries: [ArchiveEntry]

    private let url: URL

    private init(url: URL, entries: [ArchiveEntry]) throws {
        self.url = url
        self.entries = entries
    }

    func readEntry(at path: ArchivePath) -> ArchiveEntryReader? {
        guard let entry = self.entry(at: path) else {
            return nil
        }
        return MinizipEntryReader(archive: url, entry: entry)
    }

    func close() {}
}

private final class MinizipEntryReader: ArchiveEntryReader, Loggable {

    private let archive: URL
    private let entry: ArchiveEntry
    private var isClosed = false

    init(archive: URL, entry: ArchiveEntry) {
        self.archive = archive
        self.entry = entry
    }

    func close() {
        transaction {
            do {
                try _file?.close()
                isClosed = true
            } catch {
                log(.error, error)
            }
        }
    }

    func read(range: Range<UInt64>?) -> ArchiveResult<Data> {
        transaction {
            let range = range ?? 0..<entry.length

            do {
                let file = try self.file()
                try file.openEntry(at: entry.path, offset: range.lowerBound)
                return .success(try file.readFromCurrentOffset(length: UInt64(range.count)))

            } catch {
                return .failure(.readFailed(entry: entry.path, archive: archive, cause: error))
            }
        }
    }

    private var _file: MinizipFile?
    private func file() throws -> MinizipFile {
        if let file = _file {
            return file
        } else if let file = MinizipFile(url: archive) {
            _file = file
            return file
        } else {
            throw MinizipArchiveError.notAValidZIP(archive)
        }
    }

    /// Makes the access to the Minizip file thread-safe.
    @discardableResult
    private func transaction<T>(_ block: () throws -> T) rethrows -> T {
        try queue.sync {
            guard !isClosed else {
                throw MinizipArchiveError.entryAlreadyClosed(entry.path)
            }

            return try block()
        }
    }
    private let queue = DispatchQueue(label: "org.readium.r2-shared-swift.MinizipFile")

}

/// Holds an opened Minizip file and provide a bridge to its C++ API.
private final class MinizipFile {

    enum MinizipError: Error {
        case status(Int32)
        case noEntryOpened
        case readFailed
    }

    // Holds an entry's metadata.
    enum Entry {
        case file(ArchivePath, length: UInt64, compressedLength: UInt64?)
        case directory(ArchivePath)
    }

    private let file: unzFile
    private var isClosed = false
    /// Information about the currently opened entry.
    private(set) var openedEntry: (path: ArchivePath, offset: UInt64)? = nil
    /// Length of the buffer used when reading an entry's data.
    private var bufferLength: Int { 1024 * 32 }

    init?(url: URL) {
        guard let file = unzOpen64(url.path) else {
            return nil
        }
        self.file = file
    }

    deinit {
        try? close()
    }

    func close() throws {
        guard !isClosed else {
            return
        }
        try closeEntry()
        try execute { unzClose(file) }
        isClosed = true
    }

    /// Moves offset to the first entry in the archive.
    func goToFirstEntry() throws {
        try closeEntry()
        try execute { unzGoToFirstFile(file) }
    }

    /// Moves offset to the next entry in the archive.
    ///
    /// - Returns: `false` when reaching the end of the archive.
    func goToNextEntry() throws -> Bool {
        try closeEntry()

        let status = unzGoToNextFile(file)
        switch status {
        case UNZ_END_OF_LIST_OF_FILE:
            return false
        case UNZ_OK:
            return true
        default:
            throw MinizipError.status(status)
        }
    }

    /// Moves the offset to the entry at `path`.
    func goToEntry(at path: ArchivePath) throws {
        try closeEntry()
        try execute { unzLocateFile(file, path.removingPrefix("/"), nil) }
    }

    /// Reads the metadata of the entry at the current offset in the archive.
    func entryMetadataAtCurrentOffset() throws -> Entry {
        let filenameMaxSize = 1024
        var fileInfo = unz_file_info64()
        let filename = UnsafeMutablePointer<CChar>.allocate(capacity: filenameMaxSize)
        defer {
            free(filename)
        }
        memset(&fileInfo, 0, MemoryLayout<unz_file_info64>.size)
        try execute { unzGetCurrentFileInfo64(file, &fileInfo, filename, UInt(filenameMaxSize), nil, 0, nil, 0) }
        let path = String(cString: filename)

        if path.hasSuffix("/") {
            return .directory(path)
        } else {
            let isCompressed = (fileInfo.compression_method != 0)
            return .file(path,
                length: UInt64(fileInfo.uncompressed_size),
                compressedLength: isCompressed ? UInt64(fileInfo.compressed_size) : nil
            )
        }
    }

    /// Opens the entry at the given `path` and file `offset`, to read its content.
    func openEntry(at path: ArchivePath, offset: UInt64 = 0) throws {
        if let entry = openedEntry, entry.path == path, entry.offset <= offset {
            if entry.offset < offset {
                try seek(by: offset - entry.offset)
            }

        } else {
            try goToEntry(at: path)
            try execute { unzOpenCurrentFile(file) }
            openedEntry = (path: path, offset: 0)
            try seek(by: offset)
        }
    }

    /// Closes the current entry if it is opened.
    func closeEntry() throws {
        guard openedEntry != nil else {
            return
        }
        openedEntry = nil
        try execute { unzCloseCurrentFile(file) }
    }

    /// Advances the current position in the archive by the given `offset`.
    func seek(by offset: UInt64) throws {
        // Deflate is stream-based, and can't be used for random access. Therefore, if the file
        // is compressed we need to read and discard the content from the start until we reach
        // the desired offset.
        try readFromCurrentOffset(length: offset) { _, _ in }

        // For non-compressed entries, we can seek directly in the content.
        // FIXME: https://github.com/readium/r2-shared-swift/issues/98
//        return execute { return unzseek64(archive, offset, SEEK_CUR) }
    }

    /// Reads the given `length` of data at the current offset in the archive.
    func readFromCurrentOffset(length: UInt64) throws -> Data {
        guard length > 0 else {
            return Data()
        }

        var data = Data(capacity: Int(length))
        try readFromCurrentOffset(length: length) { (bytes, length) in
            data.append(bytes, count: Int(length))
        }
        return data
    }

    typealias Consumer = (_ bytes: UnsafePointer<UInt8>, _ length: UInt64) -> Void

    /// Consumes the given `length` of data at the current offset in the archive.
    func readFromCurrentOffset(length: UInt64, consumer: Consumer) throws {
        guard var entry = openedEntry else {
            throw MinizipError.noEntryOpened
        }
        guard length > 0 else {
            return
        }

        var totalBytesRead: UInt64 = 0
        defer {
            entry.offset += totalBytesRead
            openedEntry = entry
        }

        while totalBytesRead < length {
            let bytesToRead = min(UInt64(bufferLength), length - totalBytesRead)
            var buffer = Array<CUnsignedChar>(repeating: 0, count: Int(bytesToRead))
            let bytesRead = UInt64(unzReadCurrentFile(file, &buffer, UInt32(bytesToRead)))
            if bytesRead == 0 {
                break
            }
            if bytesRead > 0 {
                totalBytesRead += bytesRead
                consumer(buffer, bytesRead)
            } else {
                throw MinizipError.readFailed
            }
        }
    }

    /// Executes a Minizip statement and checks its status.
    private func execute(_ block: () -> Int32) throws {
        let status = block()
        guard status == UNZ_OK else {
            throw MinizipError.status(status)
        }
    }

}

