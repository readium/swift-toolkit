//
//  ZIPContainer.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 14/12/2016.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Specializing the Container for ZIP files.
class ArchiveContainer: Container, Loggable {

    var rootFile: RootFile
    var drm: DRM?
    
    /// The zip archive object containing the Epub.
    let archive: ZipArchive
    
    init?(path: String, mimetype: String) {
        guard let archive = ZipArchive(url: URL(fileURLWithPath: path)) else {
            ArchiveContainer.log(.error, "File at \(path) not found.")
            return nil
        }
        
        self.rootFile = RootFile(rootPath: path, mimetype: mimetype)
        self.archive = archive
    }
    
    func data(relativePath: String) throws -> Data {
        let path = fixPath(relativePath)
        return try archive.readData(path: path)
    }
    
    func dataLength(relativePath: String) throws -> UInt64 {
        let path = fixPath(relativePath)
        guard archive.locateFile(path: path) else {
            throw ContainerError.missingFile(path: relativePath)
        }
        return try archive.informationsOfCurrentFile().length
    }
    
    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        // One zipArchive instance per inputstream... for multithreading.
        let path = fixPath(relativePath)
        guard let inputStream = ZipInputStream(zipFilePath: rootFile.rootPath, path: path) else {
            throw ContainerError.streamInitFailed
        }
        return inputStream
    }
    
    /// ZipArchive doesn't expect a / at the beginning of relative paths, but Link's href have them.
    private func fixPath(_ path: String) -> String {
        if path.first == "/" {
            return String(path.dropFirst())
        } else {
            return path
        }
    }
    
}
