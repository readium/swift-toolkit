//
//  DirectoryContainer.swift
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


class DirectoryContainer: Container, Loggable {
    
    var rootFile: RootFile
    var drm: DRM?
    
    init?(directory: String, mimetype: String) {
        // FIXME: useless check probably. Always made before hand.
        guard FileManager.default.fileExists(atPath: directory) else {
            DirectoryContainer.log(.error, "File at \(directory) not found.")
            return nil
        }
        self.rootFile = RootFile(rootPath: directory, mimetype: mimetype)
    }
    
    func data(relativePath: String) throws -> Data {
        let fullPath = generateFullPath(with: relativePath)
        
        return try Data(contentsOf: URL(fileURLWithPath: fullPath), options: [.mappedIfSafe])
    }
    
    func dataLength(relativePath: String) throws -> UInt64 {
        let fullPath = generateFullPath(with: relativePath)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath),
            let fileSize = attributes[FileAttributeKey.size] as? UInt64 else
        {
            throw ContainerError.fileError
        }
        return fileSize
    }
    
    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        let fullPath = generateFullPath(with: relativePath)
        
        guard let inputStream = FileInputStream(fileAtPath: fullPath) else {
            throw ContainerError.streamInitFailed
        }
        return inputStream
    }
    
    /// Generates an absolute path to a ressource from a given relative path.
    ///
    /// - Parameter relativePath: The 'directory-relative' path to the ressource.
    /// - Returns: The absolute path to the ressource
    private func generateFullPath(with relativePath: String) -> String {
        return rootFile.rootPath.appending(pathComponent: relativePath)
    }
    
}
