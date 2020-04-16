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

final class ZFZIPEntry: ZIPEntry {
    
    fileprivate let entry: Entry
    
    init(entry: Entry) {
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

    lazy var entries: [ZIPEntry] = archive.map(ZFZIPEntry.init)

    func entry(at path: String) -> ZIPEntry? {
        return archive[path].map(ZFZIPEntry.init)
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
            var offset: UInt64 = 0
            let progress = Progress()
            
            _ = try archive.extract(entry, progress: progress) { chunk in
                let chunkLength = UInt64(chunk.count)
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
        
        return data[0..<rangeLength]
    }

}

final class ZFMutableZIPArchive: ZFZIPArchive, MutableZIPArchive {

    required convenience init(file: URL, password: String?) throws {
        try self.init(file: file, accessMode: .update)
    }

    func replace(at path: String, with data: Data, deflated: Bool) throws {
        objc_sync_enter(archive)
        defer { objc_sync_exit(archive) }
        
        do {
            // Removes the old entry if it already exists in the archive, otherwise we get
            // duplicated entries
            if let entry = entry(at: path) as? ZFZIPEntry {
                try archive.remove(entry.entry)
            }
            
            try archive.addEntry(with: path, type: .file, uncompressedSize: UInt32(data.count), compressionMethod: deflated ? .deflate : .none, provider: { position, size in
                data[position..<size]
            })
        } catch {
            log(.error, error)
            throw ZIPError.updateFailed
        }
    }
    
}
