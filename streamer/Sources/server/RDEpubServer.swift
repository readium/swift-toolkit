//
//  RDEpubServer.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import GCDWebServers


/**
 
 The HTTP server for the publication's manifests and assets
 
*/
class RDEpubServer {
    
    /// The HTTP server
    var webServer: GCDWebServer
    
    /// The dictionary of EPUB containers keyed by prefix
    var containers: [String: RDContainer] = [:]
    
    /// The dictionaty of publications keyed by prefix
    var publications: [String: RDPublication] = [:]
    
    /// The running HTTP server listening port
    var port: UInt? {
        get {
            return webServer.port
        }
    }
    
    /// The base URL of the server
    var baseURL: URL? {
        get {
            return webServer.serverURL
        }
    }
    
    init?() {
        webServer = GCDWebServer()
        do {
            try webServer.start(options: [
                GCDWebServerOption_Port: 0,
                GCDWebServerOption_BindToLocalhost: true])
        } catch {
            NSLog("Failed to start the HTTP server: \(error)")
            return nil
        }
    }
    
    /**
    
     Add an EPUB container to the list of EPUBS being served.
     
     - parameter container: The EPUB container of the publication
     - parameter prefix: The URI prefix to use to fetch assets from the publication `/{prefix}/{assetRelativePath}`
 
    */
    func addEpub(container: RDContainer, withPrefix prefix: String) {
        if containers[prefix] == nil {
            let parser = RDEpubParser(container: container)
            if let publication = try? parser.parse() {
                
                // Add self link
                if let pubURL = baseURL?.appendingPathComponent("\(prefix)/manifest.json", isDirectory: false) {
                    publication?.links.append(RDLink(href: pubURL.absoluteString, typeLink: "application/webpub+json", rel: "self"))
                }
                
                // Are these dictionaries really necessary?
                containers[prefix] = container
                publications[prefix] = publication
                
                let fetcher = RDEpubFetcher(publication: publication!, container: container)
                
                // Add the handler for the resources
                webServer.addHandler(
                    forMethod: "GET",
                    pathRegex: "/\(prefix)/.*",
                    request: GCDWebServerRequest.self,
                    processBlock: { request in
                        // TODO: check for partial range
                        
                        guard let path = request?.path else {
                            return GCDWebServerErrorResponse(statusCode: 500)
                        }
                        
                        // Remove the prefix from the URI
                        let relativePath = path.substring(from: path.index(prefix.endIndex, offsetBy: 3))
                        
                        do {
                            let typedData = try fetcher?.data(forRelativePath: relativePath)
                            return GCDWebServerDataResponse(data: typedData!.data, contentType: typedData!.mediaType)
                            
                        } catch RDEpubFetcherError.missingFile {
                            return GCDWebServerErrorResponse(statusCode: 404)
                            
                        } catch {
                            return GCDWebServerErrorResponse(statusCode: 500)
                        }
                })
                
                // Add the handler for the manifest
                webServer.addHandler(
                    forMethod: "GET",
                    pathRegex: "/\(prefix)/manifest.json",
                    request: GCDWebServerRequest.self,
                    processBlock: { request in
                        let manifestJSON = publication?.toJSONString()
                        let manifestData = manifestJSON?.data(using: .utf8)
                        return GCDWebServerDataResponse(data: manifestData, contentType: "application/json; charset=utf-8"/*"application/webpub+json; charset=utf-8"*/)
                })
                
            }
        }
    }
    
    /**
    
     Remove an EPUB container from the server
     
     - parameter prefix: The URI prefix associated with the container (by `addEpub`)
 
    */
    func removeEpub(withPrefix prefix: String) {
        if containers[prefix] != nil {
            containers[prefix] = nil
            publications[prefix] = nil
            // TODO: remove handlers
        }
    }
}
