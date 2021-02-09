//
//  Minizip.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 15/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import Minizip

/// A ZIP `Archive` using the Minizip library.
final class MinizipArchive: Archive, Loggable {

    private let archive: unzFile

    init(url: URL, password: String?) throws {
        assert(url.isFileURL, "Only file URLs are supported by MinizipArchive")
        
        guard (try? url.checkResourceIsReachable()) ?? false,
            let archive = unzOpen64(url.path) else
        {
            throw ArchiveError.openFailed
        }
        self.archive = archive

        initEntries()
    }
    
    deinit {
        close()
    }

    private(set) var entries: [ArchiveEntry] = []
    private var entriesByPath: [String: ArchiveEntry] = [:]

    private func initEntries() {
        assert(entries.isEmpty, "already initialized entries")
        guard goToFirstEntry() else {
            return
        }

        repeat {
            if let entry = makeEntryAtCurrentOffset() {
                entries.append(entry)
                entriesByPath[entry.path] = entry
            }
        } while goToNextEntry()
    }

    func entry(at path: String) throws -> ArchiveEntry {
        guard let entry = entriesByPath[path] else {
            throw ArchiveError.entryNotFound
        }
        return entry
    }
    
    func read(at path: String) -> Data? {
        return transaction {
            guard
                let length = entriesByPath[path]?.length,
                openEntry(at: path)
            else {
                return nil
            }
            defer {
                closeEntry()
            }
            return readFromCurrentOffset(length: length)
        }
    }
    
    func read(at path: String, range: Range<UInt64>) -> Data? {
        return transaction {
            guard openEntry(at: path, offset: range.lowerBound) else {
                return nil
            }

            let length = (range.upperBound - range.lowerBound)
            return readFromCurrentOffset(length: length)
        }
    }
    
    /// Makes the access to the Minizip archive thread-safe.
    @discardableResult
    private func transaction<T>(_ block: () throws -> T) rethrows -> T {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return try block()
    }
    
    func close() {
        transaction {
            closeEntry()
            unzClose(archive)
        }
    }


    // MARK: Minizip C++ Bridge

    /// Information about the currently opened entry.
    private var openedEntry: (path: String, offset: UInt64)? = nil

    /// Length of the buffer used when reading an entry's data.
    private var bufferLength: Int { 1024 * 64 }

    /// Moves offset to the first entry in the archive.
    private func goToFirstEntry() -> Bool {
        closeEntry()
        return execute { unzGoToFirstFile(archive) }
    }
    
    /// Moves offset to the next entry in the archive.
    ///
    /// - Returns: `false` in case of EOF or error.
    private func goToNextEntry() -> Bool {
        closeEntry()

        let status = unzGoToNextFile(archive)
        switch status {
        case UNZ_END_OF_LIST_OF_FILE:
            return false
        case UNZ_OK:
            return true
        default:
            log(.error, "Minizip error: #\(status)")
            return false
        }
    }
    
    /// Moves the offset to the entry at `path`.
    private func goToEntry(at path: String) -> Bool {
        closeEntry()
        return unzLocateFile(archive, path, nil) == UNZ_OK
    }
    
    /// Creates an `ArchiveEntry` from the entry at the current offset in the archive.
    private func makeEntryAtCurrentOffset() -> ArchiveEntry? {
        let filenameMaxSize = 1024
        var fileInfo = unz_file_info64()
        let filename = UnsafeMutablePointer<CChar>.allocate(capacity: filenameMaxSize)
        defer {
            free(filename)
        }
        memset(&fileInfo, 0, MemoryLayout<unz_file_info64>.size)
        guard execute({ unzGetCurrentFileInfo64(archive, &fileInfo, filename, UInt(filenameMaxSize), nil, 0, nil, 0) }) else {
            return nil
        }
        let path = String(cString: filename)
        
        // We ignore directories.
        guard !path.hasSuffix("/") else {
            return nil
        }
        
        let isCompressed = (fileInfo.compression_method != 0)
        
        return ArchiveEntry(
            path: path,
            length: UInt64(fileInfo.uncompressed_size),
            isCompressed: isCompressed,
            compressedLength: isCompressed ? UInt64(fileInfo.compressed_size) : nil
        )
    }
    
    /// Opens the entry at the given `path` and file `offset`, to read its content.
    private func openEntry(at path: String, offset: UInt64 = 0) -> Bool {
        if let entry = openedEntry, entry.path == path, entry.offset <= offset {
            if entry.offset < offset {
                return seek(by: offset - entry.offset)
            } else {
                return true
            }

        } else {
            guard
                goToEntry(at: path),
                execute({ unzOpenCurrentFile(archive) })
            else {
                return false
            }
            openedEntry = (path: path, offset: 0)
            return seek(by: offset)
        }
    }

    /// Closes the current entry if it is opened.
    private func closeEntry() {
        guard openedEntry != nil else {
            return
        }
        openedEntry = nil
        _ = execute { unzCloseCurrentFile(archive) }
    }
    
    /// Advances the current position in the archive by the given `offset`.
    ///
    /// - Returns: Whether the seeking operation was successful.
    private func seek(by offset: UInt64) -> Bool {
        // Deflate is stream-based, and can't be used for random access. Therefore, if the file
        // is compressed we need to read and discard the content from the start until we reach
        // the desired offset.
        return readFromCurrentOffset(length: offset) { _, _ in }

        // For non-compressed entries, we can seek directly in the content.
        // FIXME: https://github.com/readium/r2-shared-swift/issues/98
//        return execute { return unzseek64(archive, offset, SEEK_CUR) }
    }

    /// Reads the given `length` of data at the current offset in the archive.
    private func readFromCurrentOffset(length: UInt64) -> Data? {
        guard length > 0 else {
            return nil
        }

        var data = Data(capacity: Int(length))
        let success = readFromCurrentOffset(length: length) { (bytes, length) in
            data.append(bytes, count: Int(length))
        }
        return success ? data : nil
    }
    
    private typealias Consumer = (_ bytes: UnsafePointer<UInt8>, _ length: UInt64) -> Void
    
    /// Consumes the given `length` of data at the current offset in the archive.
    private func readFromCurrentOffset(length: UInt64, consumer: Consumer) -> Bool {
        guard var entry = openedEntry else {
            log(.error, "Trying to read while no entry was opened")
            return false
        }
        guard length > 0 else {
            return true
        }

        var buffer = Array<CUnsignedChar>(repeating: 0, count: bufferLength)

        var totalBytesRead: UInt64 = 0
        defer {
            entry.offset += totalBytesRead
            openedEntry = entry
        }

        while totalBytesRead < length {
            let bytesToRead = min(UInt64(bufferLength), length - totalBytesRead)
            let bytesRead = UInt64(unzReadCurrentFile(archive, &buffer, UInt32(bytesToRead)))
            if bytesRead == 0 {
                break
            }
            if bytesRead > 0 {
                totalBytesRead += bytesRead
                consumer(buffer, bytesRead)
            } else {
                log(.error, "Minizip error: Can't read current entry")
                return false
            }
        }
        return true
    }

    /// Executes a Minizip statement and checks its status.
    ///
    /// - Returns: Whether the statement was successful.
    private func execute(_ block: () -> Int32) -> Bool {
        let status = block()
        guard status == UNZ_OK else {
            log(.error, "Minizip error: #\(status)")
            return false
        }
        return true
    }

}
