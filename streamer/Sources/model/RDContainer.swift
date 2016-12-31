//
//  RDContainer.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation


/**
 
 EPUB container protocol, for access to raw data from the files in the container.
 
*/
protocol RDContainer {
    
    /**
     
     Get the raw (possibly encrypted) data of an asset in the container.
     
     - parameter relativePath: The relative path to the asset.
     
     - returns: The data of the asset.
     
    */
    func data(relativePath: String) throws -> Data?
}


/**
 
 EPUB Container protocol implementation for EPUBs unzipped in a directory.

*/
class RDDirectoryContainer: RDContainer {
    
    /// The root directory path
    var rootPath: String
    
    init?(directory dirPath: String) {
        rootPath = dirPath
        if !FileManager.default.fileExists(atPath: rootPath) {
            return nil
        }
    }
    
    func data(relativePath: String) throws -> Data? {
        let fullPath = (rootPath as NSString).appendingPathComponent(relativePath)
        return try Data(contentsOf: URL(fileURLWithPath: fullPath))
    }
}


/**
 
 EPUB Container protocol implementation for EPUB files
 
 */
class RDEpubContainer: RDContainer {
    
    var epubFilePath: String
    
    init?(path: String) {
        epubFilePath = path
    }
    
    func data(relativePath: String) throws -> Data? {
        // TODO
        return nil
    }
}
