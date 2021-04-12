//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An archive exploded on the file system as a directory.
final class ExplodedArchive: Archive, Loggable {

    enum ExplodedArchiveError: Error {
        case notAFileURL(URL)
        case notADirectory(URL)
    }

    private let root: URL

    public static func make(url: URL) -> ArchiveResult<ExplodedArchive> {
        guard url.isFileURL else {
            return .failure(.openFailed(archive: url, cause: ExplodedArchiveError.notAFileURL(url)))
        }

        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        guard isDirectory else {
            return .failure(.openFailed(archive: url, cause: ExplodedArchiveError.notADirectory(url)))
        }

        return .success(Self(url: url.standardizedFileURL))
    }

    private init(url: URL) {
        self.root = url.standardizedFileURL
    }
    
    lazy var entries: [ArchiveEntry] = {
        var entries: [ArchiveEntry] = []
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
            while let file = enumerator.nextObject() as? URL {
                if let entry = makeEntry(at: file) {
                    entries.append(entry)
                }
            }
        }
        return entries.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }()

    func readEntry(at path: ArchivePath) -> ArchiveEntryReader? {
        guard
            let url = entryURL(fromPath: path),
            let entry = self.entry(at: path)
        else {
            return nil
        }
        return ExplodedEntryReader(root: root, entry: entry, url: url)
    }

    func close() {}

    private func makeEntry(at url: URL) -> ArchiveEntry? {
        let url = url.standardizedFileURL
        guard
            root.isParentOf(url),
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
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
    
    private func entryURL(fromPath path: String) -> URL? {
        let url = root.appendingPathComponent(path).standardizedFileURL
        return root.isParentOf(url) ? url : nil
    }
    
}

// FIXME: Add a version for iOS 13+ using non-deprecated FileHandle APIs.
private final class ExplodedEntryReader: ArchiveEntryReader, Loggable {

    private let root: URL
    private let entry: ArchiveEntry
    private let url: URL

    init(root: URL, entry: ArchiveEntry, url: URL) {
        self.root = root
        self.entry = entry
        self.url = url
    }

    var file: URL? { url }

    func read(range: Range<UInt64>?) -> ArchiveResult<Data> {
        do {
            let range = range ?? 0..<entry.length
            let handle = try self.handle()
            if handle.offsetInFile != range.lowerBound {
                handle.seek(toFileOffset: range.lowerBound)
            }
            return .success(handle.readData(ofLength: Int(range.upperBound - range.lowerBound)))
        } catch {
            return .failure(.readFailed(entry: entry.path, archive: root, cause: error))
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
            let handle = try FileHandle(forReadingFrom: url)
            _handle = handle
            return handle
        }
    }

}