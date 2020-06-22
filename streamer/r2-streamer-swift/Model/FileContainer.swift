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


/// Container providing access to standalone files.
class FileContainer: Container, Loggable {
    
    enum File {
        case path(String)
        case data(Data)
    }
    
    var rootFile: RootFile
    var drm: DRM?
    
    /// Maps between container relative paths, and the matching File to serve.
    var files = [String: File]()

    init(path: String, mimetype: String) {
        self.rootFile = RootFile(rootPath: path, mimetype: mimetype)
    }
    
    func data(relativePath: String) throws -> Data {
        guard let file = files[relativePath] else {
            throw ContainerError.missingFile(path: relativePath)
        }
        
        switch file {
        case .path(let path):
            return try Data(contentsOf: URL(fileURLWithPath: path))
        case .data(let data):
            return data
        }
    }
    
    func dataLength(relativePath: String) throws -> UInt64 {
        guard let file = files[relativePath] else {
            throw ContainerError.missingFile(path: relativePath)
        }
        
        switch file {
        case .path(let path):
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            guard let length = attributes[FileAttributeKey.size] as? UInt64 else {
                throw ContainerError.fileError
            }
            return length
        case .data(let data):
            return UInt64(data.count)
        }
    }
    
    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        guard let file = files[relativePath] else {
            throw ContainerError.missingFile(path: relativePath)
        }
        
        let inputStream: SeekableInputStream?
        switch file {
        case .path(let path):
            inputStream = FileInputStream(fileAtPath: path)
        case .data(let data):
            inputStream = DataInputStream(data: data)
        }
        
        guard let stream = inputStream else {
            throw ContainerError.streamInitFailed
        }
        return stream
    }
    
}
