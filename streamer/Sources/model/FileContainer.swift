//
//  FileContainer.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 05.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Container providing access to a single file.
class FileContainer: Container, Loggable {
    
    var rootFile: RootFile
    var drm: DRM?
    
    /// Relative path used to access the single file, using Container's API.
    private let relativePath: String
    
    init?(path: String, relativePath: String, mimetype: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            FileContainer.log(.error, "File at \(path) not found.")
            return nil
        }
        
        self.rootFile = RootFile(rootPath: path, mimetype: mimetype)
        self.relativePath = relativePath
    }
    
    func data(relativePath: String) throws -> Data {
        guard relativePath == self.relativePath else {
            throw ContainerError.missingFile(path: relativePath)
        }
        
        return try Data(contentsOf: URL(fileURLWithPath: rootFile.rootPath))
    }
    
    func dataLength(relativePath: String) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: rootFile.rootPath)
        guard let length = attributes[FileAttributeKey.size] as? UInt64 else {
            throw ContainerError.fileError
        }
        return length
    }
    
    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        guard let inputStream = FileInputStream(fileAtPath: rootFile.rootPath) else {
            throw ContainerError.streamInitFailed
        }
        return inputStream
    }
    
}
