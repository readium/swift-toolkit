//
//  RDEpubServer.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import GCDWebServers


class RDWebServerResourceResponse: GCDWebServerFileResponse {
    
    var container: RDContainer
    var relativePath: String
    var range: Range<UInt64>
    var offset: Int64
    var length: UInt64
    let bufferSize = 32 * 1024
    
    init(container: RDContainer, relativePath: String, range: Range<UInt64>) {
        self.container = container
        self.relativePath = relativePath
        self.range = range
        self.length = UInt64(range.count)
    }
    
    override func open() throws {
        container.openFile(relativePath)
    }
    override func readData() throws -> Data {
        <#code#>
    }
    override func close() {
        <#code#>
    }
}


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
                
                // Add the handler for the resources
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
                
                // Add the handler for the resources
                webServer.addHandler(
                    forMethod: "GET",
                    pathRegex: "/\(endpoint)/.*",
                    request: GCDWebServerRequest.self,
                    processBlock: { request in

                        guard let path = request?.path else {
                            NSLog("no path in request")
                            return GCDWebServerErrorResponse(statusCode: 500)
                        }
                        
                        NSLog("request \(path)")
                        
                        // Check for partial range
                        var byteRange: Range<UInt64>
                        if request!.hasByteRange() {
                            let byteRange2 = request!.byteRange
                            NSLog("\(byteRange2)")
                            let upperBound = request!.byteRange.location + request!.byteRange.length
                            byteRange = Range<UInt64>(uncheckedBounds: (lower: UInt64(request!.byteRange.location), upper: UInt64(upperBound)))
                        } else {
                            byteRange = Range<UInt64>(uncheckedBounds: (lower: 0, upper: UInt64.max))
                        }
                        
                        // Remove the prefix from the URI
                        let relativePath = path.substring(from: path.index(endpoint.endIndex, offsetBy: 3))
                        
                        do {
                            let typedData = try fetcher?.data(forRelativePath: relativePath, range: byteRange)
                            let response = GCDWebServerDataResponse(data: typedData!.data, contentType: typedData!.mediaType)
                            
                            // Add content range header
                            if request!.hasByteRange() {
                                response?.statusCode = 206 // Partial content
                                let rangeStart = byteRange.lowerBound
                                let rangeEnd = rangeStart + UInt64(typedData!.data.count) - 1
                                let totalLength = try fetcher?.dataLength(forRelativePath: relativePath)
                                NSLog("Partial content \(path) bytes \(rangeStart)-\(rangeEnd)/\(totalLength!)")
                                response?.setValue("bytes \(rangeStart)-\(rangeEnd)/\(totalLength!)", forAdditionalHeader: "Content-Range")
                                //response?.contentLength = UInt(totalLength!)
                            }
                            
                            // Add cache-related header(s)
                            response?.cacheControlMaxAge = UInt(60 * 60 * 2)
                            return response
                            
                        } catch RDEpubFetcherError.missingFile {
                            return GCDWebServerErrorResponse(statusCode: 404)
                            
                        } catch {
                            return GCDWebServerErrorResponse(statusCode: 500)
                        }
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
