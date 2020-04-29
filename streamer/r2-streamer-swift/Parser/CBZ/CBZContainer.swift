//
//  CBZContainer.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 14/12/2016.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Specializing the `Container` for CBZ publications.
protocol CBZContainer: Container {
    
    /// Return the array of the filenames contained inside of the CBZ container.
    var files: [String] { get }
    
}


final class CBZArchiveContainer: ArchiveContainer, CBZContainer {
    
    init?(path: String) {
        super.init(path: path, mimetype: MediaType.cbz.string)
        
        do {
            try archive.buildFilesList()
        } catch {
            CBZArchiveContainer.log(.error, "zipArchive error generating file List")
            return nil
        }
    }

    var files: [String] {
        let archivedFilesList = archive.fileInfos.map({
            $0.key
        }).sorted()
        
        return archivedFilesList
    }

}


final class CBZDirectoryContainer: DirectoryContainer, CBZContainer {
    
    init?(directory: String) {
        super.init(directory: directory, mimetype: MediaType.cbz.string)
    }
    
    var files: [String] {
        guard let path =  rootFile.rootPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: path) else
        {
            return []
        }
        guard let list = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
            return []
        }
        
        return list.map({ $0.path.lastPathComponent })
    }
    
}
