//
//  ZFZIPArchive.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import ZIPFoundation

final class ZFZIPEntry: ZIPEntry, Loggable {
    
    fileprivate let archive: Archive
    fileprivate let entry: Entry
    
    init(archive: Archive, entry: Entry) {
        self.archive = archive
        self.entry = entry
    }
    
    var path: String {
        entry.path
    }
    
    var isDirectory: Bool {
        entry.type == .directory
    }
    
    var length: UInt64 {
        UInt64(entry.uncompressedSize)
    }
    
    var compressedLength: UInt64 {
        UInt64(entry.compressedSize)
    }
    
    func read() -> Data? {
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
    
}

class ZFZIPArchive: ZIPArchive, Loggable {
    
    fileprivate let archive: Archive
    
    // Note: passwords are not supported with ZIPFoundation
    required convenience init(file: URL, password: String?) throws {
        try self.init(file: file, accessMode: .read)
    }
    
    fileprivate init(file: URL, accessMode: Archive.AccessMode) throws {
        guard let archive = Archive(url: file, accessMode: accessMode) else {
            throw ZIPError.openFailed
        }
        self.archive = archive
    }

    lazy var paths: [String] = archive.map { $0.path }

    func entry(at path: String) -> ZIPEntry? {
        guard let entry = archive[path] else {
            return nil
        }
        return ZFZIPEntry(archive: archive, entry: entry)
    }

}

final class ZFMutableZIPArchive: ZFZIPArchive, MutableZIPArchive {

    required convenience init(file: URL, password: String?) throws {
        try self.init(file: file, accessMode: .update)
    }

    func removeEntry(at path: String) throws {
        guard let entry = entry(at: path) as? ZFZIPEntry else {
            return
        }
        do {
            try archive.remove(entry.entry)
        } catch {
            log(.error, error)
            throw ZIPError.updateFailed
        }
    }
    
    func addFile(at path: String, data: Data, deflated: Bool) throws {
        try addEntry(at: path, data: data, deflated: deflated)
    }
    
    func addDirectory(at path: String) throws {
        try addEntry(at: path, data: nil, deflated: false)
    }
    
    private func addEntry(at path: String, data: Data?, deflated: Bool) throws {
        // Removes the old entry if it already exists in the archive, otherwise we get duplicated
        // entries
        try removeEntry(at: path)
        
        do {
            if let data = data {
                try archive.addEntry(with: path, type: .file, uncompressedSize: UInt32(data.count), compressionMethod: deflated ? .deflate : .none, provider: { position, size in
                    data[position..<size]
                })
            } else {
                try archive.addEntry(with: path, type: .directory, uncompressedSize: 0, provider: { _, _ in
                    Data()
                })
            }
        } catch {
            log(.error, error)
            throw ZIPError.updateFailed
        }
    }
    
}
