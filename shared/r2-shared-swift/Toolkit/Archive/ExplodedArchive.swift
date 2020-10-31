//
//  ExplodedArchive.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// An archive exploded on the file system as a directory.
final class ExplodedArchive: Archive, Loggable {
    
    private let root: URL
    
    init(url: URL, password: String?) throws {
        assert(url.isFileURL, "Only file URLs are supported by ExplodedArchive")
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        guard isDirectory else {
            throw ArchiveError.openFailed
        }
        
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
    
    func entry(at path: String) throws -> ArchiveEntry {
        guard
            let url = entryURL(fromPath: path),
            let entry = makeEntry(at: url) else
        {
            throw ArchiveError.entryNotFound
        }
        return entry
    }
    
    func read(at path: String) -> Data? {
        guard let url = entryURL(fromPath: path) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
    
    func read(at path: String, range: Range<UInt64>) -> Data? {
        guard let url = entryURL(fromPath: path) else {
            return nil
        }
        
        do {
            let handle = try FileHandle(forReadingFrom: url)
            handle.seek(toFileOffset: UInt64(max(0, range.lowerBound)))
            return handle.readData(ofLength: Int(range.upperBound - range.lowerBound))
        } catch {
            log(.error, "Can't read ExplodedArchive entry: \(error)")
            return nil
        }
    }
    
    func file(at path: String) -> URL? {
        return entryURL(fromPath: path)
    }
    
    func close() {}

    private func makeEntry(at url: URL) -> ArchiveEntry? {
        let url = url.standardizedFileURL
        guard
            root.isParentOf(url),
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
            values.isDirectory != true else
        {
            return nil
        }
        
        return ArchiveEntry(
            path: url.path.removingPrefix(root.path + "/"),
            length: values.fileSize.map(UInt64.init),
            isCompressed: false,
            compressedLength: nil
        )
    }
    
    private func entryURL(fromPath path: String) -> URL? {
        let url = root.appendingPathComponent(path).standardizedFileURL
        return root.isParentOf(url) ? url : nil
    }
    
}
