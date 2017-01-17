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
        GCDWebServer.setLogLevel(0)
        webServer = GCDWebServer()
        do {
            #if DEBUG
                // Debug
                let port = 8080
            #else
                // Default: random port
                let port = 0
            #endif
            try webServer.start(options: [
                GCDWebServerOption_Port: port,
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
    func addEpub(container: RDContainer, withEndpoint endpoint: String) {
        if containers[endpoint] == nil {
            let parser = RDEpubParser(container: container)
            if let publication = try? parser.parse() {
                
                // Add self link
                if let pubURL = baseURL?.appendingPathComponent("\(endpoint)/manifest.json", isDirectory: false) {
                    publication?.links.append(RDLink(href: pubURL.absoluteString, typeLink: "application/webpub+json", rel: "self"))
                }
                
                // Are these dictionaries really necessary?
                containers[endpoint] = container
                publications[endpoint] = publication
                
                let fetcher = RDEpubFetcher(publication: publication!, container: container)
                
                // Add the handler for the resources OPTIONS
                /*
                webServer.addHandler(
                    forMethod: "OPTIONS",
                    pathRegex: "/\(endpoint)/.*",
                    request: GCDWebServerRequest.self,
                    processBlock: { request in
                        
                        guard let path = request?.path else {
                            NSLog("no path in options request")
                            return GCDWebServerErrorResponse(statusCode: 500)
                        }
                        
                        NSLog("options request \(path)")
                        
                        return GCDWebServerDataResponse()
                })
                */
                
                // Add the handler for the resources
                webServer.addHandler(
                    forMethod: "GET",
                    pathRegex: "/\(endpoint)/.*",
                    request: GCDWebServerRequest.self,
                    processBlock: { request in

                        guard request != nil else {
                            NSLog("no request")
                            return GCDWebServerErrorResponse(statusCode: 500)
                        }
                        
                        //NSLog("request \(request)")
                        //NSLog("request headers \(request!.headers)")
                        
                        guard let path = request?.path else {
                            NSLog("no path in request")
                            return GCDWebServerErrorResponse(statusCode: 500)
                        }
                        
                        NSLog("request \(path)")
                        
                        // Remove the prefix from the URI
                        let relativePath = path.substring(from: path.index(endpoint.endIndex, offsetBy: 3))
                        let resource = publication?.resource(withRelativePath: relativePath)
                        let contentType = resource?.typeLink ?? "application/octet-stream"
                        
                        var response: GCDWebServerResponse
                        do {
                            // Get a data input stream from the fetcher
                            if let dataStream = try fetcher?.dataStream(forRelativePath: relativePath) {
                                let range: NSRange? = request!.hasByteRange() ? request!.byteRange : nil
                                let r = RDWebServerResourceResponse(inputStream: dataStream, range: range, contentType: contentType)
                                response = r
                            } else {
                                // Error getting the data stream
                                NSLog("Unable to get a data stream from the fetcher")
                                response = GCDWebServerErrorResponse(statusCode: 500)
                            }
                            
                        } catch RDEpubFetcherError.missingFile {
                            // File not found
                            response = GCDWebServerErrorResponse(statusCode: 404)
                            
                        } catch {
                            // Any other error
                            NSLog("General error creating the response \(error)")
                            response = GCDWebServerErrorResponse(statusCode: 500)
                        }
                        
                        return response
                })
                
                // Add the handler for the manifest
                webServer.addHandler(
                    forMethod: "GET",
                    pathRegex: "/\(endpoint)/manifest.json",
                    request: GCDWebServerRequest.self,
                    processBlock: { request in
                        let manifestJSON = publication?.toJSONString()
                        let manifestData = manifestJSON?.data(using: .utf8)
                        return GCDWebServerDataResponse(data: manifestData, contentType: "application/webpub+json; charset=utf-8")
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
