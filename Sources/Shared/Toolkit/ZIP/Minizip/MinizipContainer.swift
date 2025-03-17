//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Minizip

/// A ZIP ``Container`` using the Minizip library.
final class MinizipContainer: Container, Loggable {
    enum MakeError: Error {
        case notAZIP
        case reading(ReadError)
    }

    static func make(file: FileURL) async -> Result<MinizipContainer, MakeError> {
        guard await (try? file.exists()) ?? false else {
            return .failure(.reading(.access(.fileSystem(.fileNotFound(nil)))))
        }
        guard let zipFile = MinizipFile(url: file.url) else {
            return .failure(.notAZIP)
        }
        defer { try? zipFile.close() }

        do {
            var entries = [RelativeURL: MinizipEntryMetadata]()

            try zipFile.goToFirstEntry()
            repeat {
                switch try zipFile.entryMetadataAtCurrentOffset() {
                case let .file(path, length: length, compressedLength: compressedLength):
                    if let url = RelativeURL(path: path) {
                        entries[url] = MinizipEntryMetadata(length: length, compressedLength: compressedLength)
                    }
                case .directory:
                    // Directories are ignored
                    break
                }
            } while try zipFile.goToNextEntry()

            return .success(Self(file: file, entries: entries))

        } catch {
            return .failure(.reading(.decoding(error)))
        }
    }

    private let file: FileURL
    private let entriesMetadata: [RelativeURL: MinizipEntryMetadata]

    public var sourceURL: AbsoluteURL? { file }
    public let entries: Set<AnyURL>

    private init(file: FileURL, entries: [RelativeURL: MinizipEntryMetadata]) {
        self.file = file
        entriesMetadata = entries
        self.entries = Set(entries.keys.map(\.anyURL))
    }

    subscript(url: any URLConvertible) -> (any Resource)? {
        guard
            let url = url.anyURL.relativeURL?.normalized,
            let metadata = entriesMetadata[url]
        else {
            return nil
        }
        return MinizipResource(file: file, entryPath: url.path, metadata: metadata)
    }
}

private struct MinizipEntryMetadata {
    let length: UInt64
    let compressedLength: UInt64?
}

private actor MinizipResource: Resource, Loggable {
    private let file: FileURL
    private let entryPath: String
    private let metadata: MinizipEntryMetadata

    init(file: FileURL, entryPath: String, metadata: MinizipEntryMetadata) {
        self.file = file
        self.entryPath = entryPath
        self.metadata = metadata
    }

    nonisolated func close() {
        Task { await doClose() }
    }

    func doClose() async {
        do {
            try _zipFile?.getOrNil()?.close()
            _zipFile = .failure(.unsupportedOperation(DebugError("The Minizip resource is already closed")))
        } catch {
            log(.error, error)
        }
    }

    public let sourceURL: AbsoluteURL? = nil

    func estimatedLength() async -> ReadResult<UInt64?> {
        .success(metadata.length)
    }

    func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties {
            $0.filename = RelativeURL(path: entryPath)?.lastPathSegment
            $0.archive = ArchiveProperties(
                entryLength: metadata.compressedLength ?? metadata.length,
                isEntryCompressed: metadata.compressedLength != nil
            )
        })
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        let range = range ?? 0 ..< metadata.length

        return await zipFile().flatMap { zipFile in
            do {
                try zipFile.openEntry(at: entryPath, offset: range.lowerBound)
                try consume(zipFile.readFromCurrentOffset(length: UInt64(range.count)))
                return .success(())
            } catch {
                return .failure(.decoding(error))
            }
        }
    }

    private var _zipFile: ReadResult<MinizipFile>?
    private func zipFile() async -> ReadResult<MinizipFile> {
        if _zipFile == nil {
            if let zipFile = MinizipFile(url: file.url) {
                _zipFile = .success(zipFile)
            } else {
                _zipFile = .failure(.decoding("Failed to open the ZIP file with Minizip"))
            }
        }
        return _zipFile!
    }
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
        case file(String, length: UInt64, compressedLength: UInt64?)
        case directory(String)
    }

    private let file: unzFile
    private var isClosed = false
    /// Information about the currently opened entry.
    private(set) var openedEntry: (path: String, offset: UInt64)?
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
    func goToEntry(at path: String) throws {
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
                         compressedLength: isCompressed ? UInt64(fileInfo.compressed_size) : nil)
        }
    }

    /// Opens the entry at the given `path` and file `offset`, to read its content.
    func openEntry(at path: String, offset: UInt64 = 0) throws {
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
        try readFromCurrentOffset(length: length) { bytes, length in
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
            var buffer = [CUnsignedChar](repeating: 0, count: Int(bytesToRead))
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
