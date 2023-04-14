//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ZIPFoundation

/// A ZIP `Archive` using the ZIPFoundation library.
///
/// Note: At the moment, the Minizip version is used. Keeping this in case we migrate to
/// ZIPFoundation.
final class ZIPFoundationArchive: Archive, Loggable {
    fileprivate let archive: ZIPFoundation.Archive

    // Note: passwords are not supported with ZIPFoundation
    required convenience init(file: URL, password: String?) throws {
        try self.init(file: file, accessMode: .read)
    }

    fileprivate init(file: URL, accessMode: Archive.AccessMode) throws {
        guard let archive = Archive(url: file, accessMode: accessMode) else {
            throw ArchiveError.openFailed
        }
        self.archive = archive
    }

    lazy var entries: [ArchiveEntry] = archive.map(ArchiveEntry.init)

    func entry(at path: String) -> ArchiveEntry? {
        archive[path]
            .filter { $0.type != .directory }
            .map(ArchiveEntry.init)
    }

    func read(at path: String) -> Data? {
        objc_sync_enter(archive)
        defer { objc_sync_exit(archive) }

        guard let entry = archive[path] else {
            return nil
        }

        do {
            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
            return data
        } catch {
            log(.error, error)
            return nil
        }
    }

    func read(at path: String, range: Range<UInt64>) -> Data? {
        objc_sync_enter(archive)
        defer { objc_sync_exit(archive) }

        guard let entry = archive[path] else {
            return nil
        }

        let rangeLength = range.upperBound - range.lowerBound
        var data = Data()

        do {
            var offset = 0
            let progress = Progress()

            _ = try archive.extract(entry, progress: progress) { chunk in
                let chunkLength = chunk.count
                defer {
                    offset += chunkLength
                    if offset >= range.upperBound {
                        progress.cancel()
                    }
                }

                guard offset < range.upperBound, offset + chunkLength >= range.lowerBound else {
                    return
                }

                let startingIndex = (range.lowerBound > offset)
                    ? (range.lowerBound - offset)
                    : 0
                data.append(chunk[startingIndex...])
            }
        } catch {
            switch error {
            case Archive.ArchiveError.cancelledOperation:
                break
            default:
                log(.error, error)
                return nil
            }
        }

        return data[0 ..< rangeLength]
    }
}

final class MutableZIPFoundationArchive: ZIPFoundationArchive, MutableArchive {
    required convenience init(file: URL, password: String?) throws {
        try self.init(file: file, accessMode: .update)
    }

    func replace(at path: String, with data: Data, deflated: Bool) throws {
        objc_sync_enter(archive)
        defer { objc_sync_exit(archive) }

        do {
            // Removes the old entry if it already exists in the archive, otherwise we get
            // duplicated entries
            if let entry = archive[path] {
                try archive.remove(entry)
            }

            try archive.addEntry(with: path, type: .file, uncompressedSize: UInt32(data.count), compressionMethod: deflated ? .deflate : .none, provider: { position, size in
                data[position ..< size]
            })
        } catch {
            log(.error, error)
            throw ArchiveError.updateFailed
        }
    }
}

private extension ArchiveEntry {
    init(entry: Entry) {
        self.init(
            path: entry.path,
            length: entry.uncompressedSize,
            compressedLength: entry.compressedSize
        )
    }
}
