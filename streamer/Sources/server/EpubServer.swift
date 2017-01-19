//
//  EpubServer.swift
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
open class EpubServer {
    
    /// The HTTP server
    var webServer: GCDWebServer
    
    /// The dictionary of EPUB containers keyed by prefix
    var containers: [String: Container] = [:]
    
    /// The dictionaty of publications keyed by prefix
    var publications: [String: Publication] = [:]
    
    /// The running HTTP server listening port
    public var port: UInt? {
        get {
            return webServer.port
        }
    }
    
    /// The base URL of the server
    public var baseURL: URL? {
        get {
            return webServer.serverURL
        }
    }
    
    public init?() {
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
     - parameter endpoint: The URI prefix to use to fetch assets from the publication `/{prefix}/{assetRelativePath}`
    */
    open func addEpub(container: Container, withEndpoint endpoint: String) {
        if containers[endpoint] == nil {
            let parser = EpubParser(container: container)
            if let publication = try? parser.parse() {
                
                // Add self link
                if let pubURL = baseURL?.appendingPathComponent("\(endpoint)/manifest.json", isDirectory: false) {
                    publication?.links.append(Link(href: pubURL.absoluteString, typeLink: "application/webpub+json", rel: "self"))
                }
                
                // Are these dictionaries really necessary?
                containers[endpoint] = container
                publications[endpoint] = publication
                
                let fetcher = EpubFetcher(publication: publication!, container: container)
                
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
                                let r = WebServerResourceResponse(inputStream: dataStream, range: range, contentType: contentType)
                                response = r
                            } else {
                                // Error getting the data stream
                                NSLog("Unable to get a data stream from the fetcher")
                                response = GCDWebServerErrorResponse(statusCode: 500)
                            }
                            
                        } catch EpubFetcherError.missingFile {
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
    open func removeEpub(withEndpoint endpoint: String) {
        if containers[endpoint] != nil {
            containers[endpoint] = nil
            publications[endpoint] = nil
            // TODO: remove handlers
        }
    }
}
