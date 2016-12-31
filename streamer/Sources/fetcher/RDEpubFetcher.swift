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
 
    Gets all the data from an asset file in a publication's container.
 
    - parameter path: The relative path to the asset in the publication.
    
    - returns: a tuple with the data and the media type if the asset was found.
    - throws: `RDEpubFetcherError.missingFile` if the file is missing from the container
 
    */
    func data(forRelativePath path: String) throws -> (data: Data, mediaType: String?)? {
        
        // Get the link information from the publication
        let assetLink = publication.resource(withRelativePath: path)
        if assetLink == nil {
            throw RDEpubFetcherError.missingFile(path: path)
        }
        // Get the media type from the link
        let mediaType = assetLink!.typeLink
        
        // Build the path relative to the container and get the data from the container
        let pubRelativePath = (rootFileDirectory as NSString).appendingPathComponent(path)
        do {
            let data = try container.data(relativePath: pubRelativePath)
            return (data!, mediaType)
        } catch {
            throw RDEpubFetcherError.missingFile(path: pubRelativePath)
        }
    }
    
    /**
     
     Gets the data from range in an asset file in a publication's container.
     
     - parameter path: The relative path to the asset in the publication.
     - parameter range: The range of the desired data.
     
     - returns: a tuple with the data and the media type if the asset was found.
     - throws: `RDEpubFetcherError.missingFile` if the file is missing from the container
     
    */
    func data(forRelativePath path: String, range: Range<CUnsignedLongLong>) -> (Data, String?)? {
        // TODO: implement range access
        return nil
    }
}
