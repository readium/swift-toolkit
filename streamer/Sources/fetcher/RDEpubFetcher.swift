//
//  RDEpubFetcher.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation


/**
 Error thrown by the `RDEpubFetcher`
 
 - missingFile
 - decryptionFailed
*/
enum RDEpubFetcherError: Error {
    case missingFile(path: String)
    case decryptionFailed
}


struct RDResourceData {
    var mediaType: String
    var data: Data
    var dataRange: Range<UInt64>
    var dataTotalLength: UInt64
}


/**
 A RDEpubFetcher object lets you get the data from the assets in the EPUB container.
 It will fetch the data in the container and apply content filters (decryption for example).
*/
class RDEpubFetcher {
    
    /// The publication to fetch from
    var publication: RDPublication
    
    /// The container to access the resources from
    var container: RDContainer
    
    /// The relative path to the directory holding the resources in the container
    var rootFileDirectory: String
    
    // TODO: Content filters
    //var contentFilters: [RDContentFilter]
    
    init?(publication: RDPublication, container: RDContainer) {
        
        // Shouldn't the publication have a property with the container?
        self.container = container
        self.publication = publication
        
        // Get the path of the directory of the rootFile, to access resources relative to the rootFile
        if let rootfilePath = publication.internalData["rootfile"] as NSString? {
            rootFileDirectory = rootfilePath.deletingLastPathComponent
        } else {
            NSLog("No rootFile in internalData, unable to get path to publication")
            return nil
        }
    }
    
    /**
     Gets all the data from an resource file in a publication's container.
 
     - parameter path: The relative path to the asset in the publication.
    
     - returns: The decrypted data of the asset.
     - throws: `RDEpubFetcherError.missingFile` if the file is missing from the container
    */
    func data(forRelativePath path: String) throws -> Data? {
        
        // Get the link information from the publication
        let assetLink = publication.resource(withRelativePath: path)
        if assetLink == nil {
            throw RDEpubFetcherError.missingFile(path: path)
        }
        
        // Build the path relative to the container and get the data from the container
        let pubRelativePath = (rootFileDirectory as NSString).appendingPathComponent(path)
        do {
            // Get the data from the container
            let data = try container.data(relativePath: pubRelativePath)
            // TODO: content filters
            
            return data
            
        } catch {
            throw RDEpubFetcherError.missingFile(path: pubRelativePath)
        }
    }
    
    /**
     Get the total length of the data in an resource file.
     
     - parameter path: The relative path to the asset in the publication.
     
     - returns: The length of the data.
     - throws: `RDEpubFetcherError.missingFile` if the file is missing from the container
    */
    func dataLength(forRelativePath path: String) throws -> UInt64 {
        
        // Get the link information from the publication
        let assetLink = publication.resource(withRelativePath: path)
        if assetLink == nil {
            throw RDEpubFetcherError.missingFile(path: path)
        }
        
        // Build the path relative to the container and get the data from the container
        let pubRelativePath = (rootFileDirectory as NSString).appendingPathComponent(path)
        do {
            // Get the data from the container
            let length = try container.dataLength(relativePath: pubRelativePath)
            return length
            
        } catch {
            throw RDEpubFetcherError.missingFile(path: pubRelativePath)
        }
    }
    
    /**
     Get an input stream with the data of the resource.
     
     - parameter path: The relative path to the asset in the publication.
     
     - returns: A seekable input stream with the decrypted data if the resource.
     - throws: `RDEpubFetcherError.missingFile` if the file is missing from the container
    */
    func dataStream(forRelativePath path: String) throws -> SeekableInputStream {
        
        // Get the link information from the publication
        let assetLink = publication.resource(withRelativePath: path)
        if assetLink == nil {
            throw RDEpubFetcherError.missingFile(path: path)
        }
        
        // Build the path relative to the container and get the data from the container
        let pubRelativePath = (rootFileDirectory as NSString).appendingPathComponent(path)

        // Get an input stream from the container
        let inputStream = try container.dataInputStream(relativePath: pubRelativePath)
        // TODO: content filters
        
        return inputStream
    }
}
