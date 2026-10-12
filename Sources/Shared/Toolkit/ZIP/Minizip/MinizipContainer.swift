//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
                    if let url = RelativeURL(zipEntryPath: path) {
                        // Key the entry under its normalized (slash-free)
                        // relative URL, but remember the original stored name
                        // so reads can locate it verbatim in the archive — some
                        // archives store leading-slash names (e.g. `/001.jpg`)
                        // that `unzLocateFile` only matches exactly.
                        entries[url] = MinizipEntryMetadata(path: path, length: length, compressedLength: compressedLength)
                    }
                case .directory:
                    // Directories are ignored
                    break
                }
            } while try zipFile.goToNextEntry()

            return .success(Self(file: file, entries: entries))

        } catch {
            return .failure(.reading(.wrap(error) ?? .decoding(error)))
        }
    }

    private let file: FileURL
    private let entriesMetadata: [RelativeURL: MinizipEntryMetadata]

    var sourceURL: AbsoluteURL? {
        file
    }

    let entries: Set<AnyURL>

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
        return MinizipResource(file: file, entryPath: metadata.path, metadata: metadata)
    }
}

private struct MinizipEntryMetadata {
    /// The entry's name exactly as stored in the archive's central directory,
    /// which may differ from its normalized lookup key (e.g. a leading slash).
    /// Used to locate the entry verbatim when reading.
    let path: String
    let length: UInt64
    let compressedLength: UInt64?
}

actor MinizipResource: Resource, Loggable {
    private let file: FileURL
    private let entryPath: String
    private let metadata: MinizipEntryMetadata

    fileprivate init(file: FileURL, entryPath: String, metadata: MinizipEntryMetadata) {
        self.file = file
        self.entryPath = entryPath
        self.metadata = metadata
    }

    /// Closing is best-effort: the underlying file is closed asynchronously,
    /// and in any case when this resource is deallocated.
    nonisolated func close() {
        Task { await doClose() }
    }

    func doClose() async {
        do {
            if case let .success(.minizip(zipFile)) = _source {
                try zipFile.close()
            }
        } catch {
            log(.error, error)
        }
        // A file handle is closed when it is released, once the streams
        // reading from it have ended.
        _source = .failure(.unsupportedOperation(DebugError("The Minizip resource is already closed")))
    }

    let sourceURL: AbsoluteURL? = nil

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

    /// Streams the content of the entry in chunks.
    ///
    /// A stored entry is read directly in the archive: its streams are
    /// independent, and reaching the start of the range costs nothing.
    ///
    /// Any other entry is read by Minizip, which holds a single position in
    /// the archive and only moves forward: a range before this position is
    /// reached by reading the entry again from its start. The stream therefore
    /// runs until its end without suspending: another stream on the same entry
    /// waits until this one ends or is cancelled.
    func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        let length = metadata.length
        let range = (range ?? 0 ..< length).clamped(to: 0 ..< length)
        guard !range.isEmpty else {
            return .success(())
        }

        switch source() {
        case let .success(.fileHandle(handle, dataRange: dataRange)):
            let start = dataRange.lowerBound
            return await handle.stream(
                range: ((start + range.lowerBound) ..< (start + range.upperBound)).clamped(to: dataRange),
                consume: consume
            )

        case let .success(.minizip(zipFile)):
            do {
                try zipFile.openEntry(at: entryPath, offset: range.lowerBound)
                try zipFile.readFromCurrentOffset(length: UInt64(range.count)) { bytes, length in
                    consume(Data(bytes: bytes, count: Int(length)))
                }
                return .success(())
            } catch {
                return .failure(.wrap(error) ?? .decoding(error))
            }

        case let .failure(error):
            return .failure(error)
        }
    }

    /// What reads the content of the entry.
    private enum Source {
        /// A file handle on the archive, for a stored entry whose data is at
        /// the given range of the archive.
        case fileHandle(FileHandle, dataRange: Range<UInt64>)
        /// Minizip, for any other entry.
        case minizip(MinizipFile)
    }

    private var _source: ReadResult<Source>?
    private func source() -> ReadResult<Source> {
        if _source == nil {
            _source = makeSource()
        }
        return _source!
    }

    private func makeSource() -> ReadResult<Source> {
        guard let zipFile = MinizipFile(url: file.url) else {
            return .failure(.decoding("Failed to open the ZIP file with Minizip"))
        }

        if
            metadata.compressedLength == nil,
            let dataRange = try? zipFile.dataRangeOfStoredEntry(at: entryPath),
            let handle = try? FileHandle(forReadingFrom: file.url)
        {
            try? zipFile.close()
            return .success(.fileHandle(handle, dataRange: dataRange))
        }

        return .success(.minizip(zipFile))
    }
}

/// Holds an opened Minizip file and provide a bridge to its C++ API.
private final class MinizipFile {
    enum MinizipError: Error {
        case status(Int32)
        case noEntryOpened
    }

    /// Holds an entry's metadata.
    enum Entry {
        case file(String, length: UInt64, compressedLength: UInt64?)
        case directory(String)
    }

    private let file: unzFile
    private var isClosed = false
    /// Information about the currently opened entry.
    private(set) var openedEntry: (path: String, offset: UInt64)?
    /// Length of the buffer used when reading an entry's data.
    private var bufferLength: Int {
        1024 * 32
    }

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
        // Locate by the exact stored name first — `unzLocateFile` matches the
        // central-directory name verbatim, so an entry stored with a leading
        // slash (e.g. `/001.jpg`) is only found by its full name. Fall back to
        // the slash-stripped name so a slash-prefixed query still resolves an
        // entry that was stored slash-free.
        do {
            try execute { unzLocateFile(file, path, nil) }
        } catch {
            try execute { unzLocateFile(file, path.removingPrefix("/"), nil) }
        }
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

    /// Returns the range in the archive file of the data of the stored entry
    /// at `path`, which can be read directly from the file.
    ///
    /// Returns `nil` when the entry is not stored, or when the range cannot be
    /// determined.
    func dataRangeOfStoredEntry(at path: String) throws -> Range<UInt64>? {
        try goToEntry(at: path)

        var fileInfo = unz_file_info64()
        try execute { unzGetCurrentFileInfo64(file, &fileInfo, nil, 0, nil, 0, nil, 0) }
        var globalInfo = unz_global_info64()
        try execute { unzGetGlobalInfo64(file, &globalInfo) }
        guard
            fileInfo.compression_method == 0,
            // The data of an entry of a split archive may be in another file.
            fileInfo.disk_num_start == globalInfo.number_disk_with_CD
        else {
            return nil
        }

        try execute { unzOpenCurrentFile(file) }
        defer { unzCloseCurrentFile(file) }

        let offset = unzGetCurrentFileZStreamPos64(file)
        guard offset > 0 else {
            return nil
        }
        return offset ..< offset + min(fileInfo.compressed_size, fileInfo.uncompressed_size)
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
    }

    typealias Consumer = (_ bytes: UnsafePointer<UInt8>, _ length: UInt64) -> Void

    /// Consumes the given `length` of data at the current offset in the archive.
    func readFromCurrentOffset(length: UInt64, consumer: Consumer) throws {
        guard openedEntry != nil else {
            throw MinizipError.noEntryOpened
        }
        guard length > 0 else {
            return
        }

        var totalBytesRead: UInt64 = 0
        defer {
            openedEntry?.offset += totalBytesRead
        }

        while totalBytesRead < length {
            try Task.checkCancellation()

            let bytesToRead = min(UInt64(bufferLength), length - totalBytesRead)
            var buffer = [CUnsignedChar](repeating: 0, count: Int(bytesToRead))
            let bytesRead = unzReadCurrentFile(file, &buffer, UInt32(bytesToRead))
            guard bytesRead >= 0 else {
                // The position of Minizip in the entry is unknown after a
                // failure, so the next read opens it again.
                try? closeEntry()
                throw MinizipError.status(bytesRead)
            }
            if bytesRead == 0 {
                break
            }
            totalBytesRead += UInt64(bytesRead)
            consumer(buffer, UInt64(bytesRead))
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
