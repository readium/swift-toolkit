//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An archive exploded on the file system as a directory.
final class ExplodedArchive: Archive, Loggable {
    enum ExplodedArchiveError: Error {
        case notADirectory(FileURL)
    }

    private let root: FileURL

    public static func make(file: FileURL) -> ArchiveResult<ExplodedArchive> {
        guard (try? file.isDirectory()) == true else {
            return .failure(.openFailed(archive: file.string, cause: ExplodedArchiveError.notADirectory(file)))
        }

        return .success(Self(file: file))
    }

    private init(file: FileURL) {
        root = file
    }

    lazy var entries: [ArchiveEntry] = {
        var entries: [ArchiveEntry] = []
        if let enumerator = FileManager.default.enumerator(at: root.url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
            while let file = enumerator.nextObject() as? URL {
                if let file = FileURL(url: file), let entry = makeEntry(at: file) {
                    entries.append(entry)
                }
            }
        }
        return entries.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }()

    func readEntry(at path: ArchivePath) -> ArchiveEntryReader? {
        guard
            let url = entryURL(fromPath: path),
            let entry = entry(at: path)
        else {
            return nil
        }
        return ExplodedEntryReader(root: root, entry: entry, url: url)
    }

    func close() {}

    private func makeEntry(at url: FileURL) -> ArchiveEntry? {
        guard
            root.isParent(of: url),
            let values = try? url.url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
            let length = values.fileSize,
            values.isDirectory != true
        else {
            return nil
        }

        return ArchiveEntry(
            path: url.path.removingPrefix(root.path).addingPrefix("/"),
            length: UInt64(length),
            compressedLength: nil
        )
    }

    private func entryURL(fromPath path: String) -> FileURL? {
        let url = root.appendingPath(path, isDirectory: false)
        guard
            root.isParent(of: url)
        else {
            return nil
        }
        return url
    }
}

// FIXME: Add a version for iOS 13+ using non-deprecated FileHandle APIs.
private final class ExplodedEntryReader: ArchiveEntryReader, Loggable {
    private let root: FileURL
    private let entry: ArchiveEntry
    private let url: FileURL

    init(root: FileURL, entry: ArchiveEntry, url: FileURL) {
        self.root = root
        self.entry = entry
        self.url = url
    }

    var file: FileURL? { url }

    func read(range: Range<UInt64>?) -> ArchiveResult<Data> {
        do {
            let range = range ?? 0 ..< entry.length
            let handle = try handle()
            if handle.offsetInFile != range.lowerBound {
                handle.seek(toFileOffset: range.lowerBound)
            }
            return .success(handle.readData(ofLength: Int(range.upperBound - range.lowerBound)))
        } catch {
            return .failure(.readFailed(entry: entry.path, archive: root.string, cause: error))
        }
    }

    func close() {
        _handle?.closeFile()
    }

    private var _handle: FileHandle?
    private func handle() throws -> FileHandle {
        if let handle = _handle {
            return handle
        } else {
            let handle = try FileHandle(forReadingFrom: url.url)
            _handle = handle
            return handle
        }
    }
}
