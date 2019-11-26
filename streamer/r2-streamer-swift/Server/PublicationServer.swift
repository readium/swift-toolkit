//
//  PublicationServer.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 21/12/2016.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared
import GCDWebServer

extension PublicationServer: Loggable {}

/// Errors thrown by the `PublicationServer`.
///
/// - parser: An error thrown by the Parser.
/// - fetcher: An error thrown by the Fetcher.
/// - nilBaseUrl: The base url is nil.
/// - usedEndpoint: This endpoint is already in use.
public enum PublicationServerError: Error{
    case parser(underlyingError: Error)
    case fetcher(underlyingError: Error)
    case nilBaseURL
    case usedEndpoint
}

/// The HTTP server for the publication's manifests and assets. Serves Epubs.
public class PublicationServer: ResourcesServer {
    /// The HTTP server.
    var webServer: GCDWebServer
    
    // Mapping between endpoint and the matching publication.
    public private(set) var publications: [String: Publication] = [:]
    
    // Mapping between endpoint and the matching container.
    public private(set) var containers: [String: Container] = [:]

    /// The port is initially set to 0 to choose a random port when first starting the server.
    /// Only the first time the server is started a random port is chosen, to make sure we keep the same port when coming out of background.
    public var port: UInt {
        return webServer.port
    }
    
    /// The base URL of the server
    public var baseURL: URL? {
        return webServer.serverURL
    }
    

    // MARK: - Public methods
    
    public init?() {
        #if DEBUG
        GCDWebServer.setLogLevel(2)
        #else
        GCDWebServer.setLogLevel(3)
        #endif
        webServer = GCDWebServer()
        if startWebServer() == false {
            return nil
        }
        addSpecialResourcesHandlers()
    }
    
    func startWebServer() -> Bool {
        func makeRandomPort() -> UInt {
            // https://en.wikipedia.org/wiki/Ephemeral_port#Range
            let lowerBound = 49152
            let upperBound = 65535
            return UInt(lowerBound + Int(arc4random_uniform(UInt32(upperBound - lowerBound))))
        }
        
        for _ in 1...10 {
            do {
                // TODO: Check if we can use unix socket instead of tcp.
                //       Check if it's supported by WKWebView first.
                try webServer.start(options: [
                    GCDWebServerOption_Port: makeRandomPort(),
                    GCDWebServerOption_BindToLocalhost: true]
                )
                return true
            } catch {
                log(.error, error)
            }
        }
        
        log(.error, "Failed to start the HTTP server")
        return false
    }
    
    // Add handlers for the css/js/font resources.
    public func addSpecialResourcesHandlers() {
        guard let resourceURL = Bundle(for: PublicationServer.self).resourceURL else {
            return
        }
        
        do {
            try serve(resourceURL.appendingPathComponent("styles"), at: "/styles")
            try serve(resourceURL.appendingPathComponent("scripts"), at: "/scripts")
            try serve(resourceURL.appendingPathComponent("fonts"), at: "/fonts")
        } catch {
            log(.error, error)
        }
    }
    
    /// Add a publication to the server.
    ///
    /// - Parameters:
    ///   - publication: The `Publication` object containing the publication data.
    ///   - container: The `Container` object giving access to the resources.
    ///   - endpoint: The relative URL to access the resource on the server. The
    ///               default value is a unique generated id.
    /// - Throws: `PublicationServerError.usedEndpoint`,
    ///           `PublicationServerError.nilBaseUrl`,
    ///           `PublicationServerError.fetcher`.
    public func add(_ publication: Publication,
                    with container: Container,
                    at endpoint: String = UUID().uuidString) throws {
        // TODO: verif that endpoint is a simple string and not a path.
        guard publications[endpoint] == nil else {
            log(.error, "\(endpoint) is already in use.")
            throw PublicationServerError.usedEndpoint
        }
        guard let baseURL = baseURL else {
            log(.error, "Base URL is nil.")
            throw PublicationServerError.nilBaseURL
        }
        
        // Add the self link to the publication.
        publication.addSelfLink(endpoint: endpoint, for: baseURL)
        
        publications[endpoint] = publication
        containers[endpoint] = container
        
        /// Add resources handler.
        do {
            try addResourcesHandler(for: publication, container: container, at: endpoint)
        } catch {
            throw PublicationServerError.fetcher(underlyingError: error)
        }
        /// Add manifest handler.
        addManifestHandler(for: publication, at: endpoint)
        
        log(.info, "Publication at \(endpoint) has been successfully added.")
    }
    
    fileprivate func addResourcesHandler(for publication: Publication, container: Container, at endpoint: String) throws {
        let fetcher: Fetcher
        
        // Initialize the Fetcher.
        do {
            fetcher = try Fetcher(publication: publication, container: container)
        } catch {
            log(.error, "Fetcher initialisation failed.")
            throw PublicationServerError.fetcher(underlyingError: error)
        }
        
        /// Webserver HTTP GET ressources request handler.
        func resourcesHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            let response: GCDWebServerResponse
            
            guard let request = request else {
                log(.error, "The request received is nil.")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            
            // Remove the prefix from the URI.
            let relativePath = String(request.path[request.path.index(endpoint.endIndex, offsetBy: 1)...])
            //
            let resource = publication.resource(withRelativePath: relativePath)
            let contentType = resource?.type ?? "application/octet-stream"
            // Get a data input stream from the fetcher.
            do {
                let dataStream = try fetcher.dataStream(forRelativePath: relativePath)
                let range = request.hasByteRange() ? request.byteRange : nil
                
                response = WebServerResourceResponse(inputStream: dataStream,
                                                     range: range,
                                                     contentType: contentType)
            } catch FetcherError.missingFile {
                log(.error, "File not found, couldn't create stream.")
                response = GCDWebServerErrorResponse(statusCode: 404)
            } catch FetcherError.container {
                log(.error, "Error while getting data stream from container.")
                response = GCDWebServerErrorResponse(statusCode: 500)
            } catch {
                log(.error, error)
                response = GCDWebServerErrorResponse(statusCode: 500)
            }
            return response
        }
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "/\(endpoint)/.*",
            request: GCDWebServerRequest.self,
            processBlock: resourcesHandler)
    }
    
    fileprivate func addManifestHandler(for publication: Publication, at endpoint: String) {
        /// The webserver handler to process the HTTP GET
        func manifestHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            guard let manifestData = publication.manifest else {
                return GCDWebServerResponse(statusCode: 404)
            }
            let type = "application/webpub+json; charset=utf-8"
            return GCDWebServerDataResponse(data: manifestData, contentType: type)
        }
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "/\(endpoint)/manifest.json",
            request: GCDWebServerRequest.self,
            processBlock: manifestHandler
        )
    }
    
    public func remove(_ publication: Publication) {
        guard let endpoint = publications.first(where: { $0.value.metadata.identifier == publication.metadata.identifier })?.key else {
            return
        }
        remove(at: endpoint)
    }
    
    /// Remove a publication from the server.
    ///
    /// - Parameter endpoint: The URI postfix of the ressource.
    public func remove(at endpoint: String) {
        guard let publication = publications[endpoint] else {
            log(.warning, "Nothing at endpoint \(endpoint).")
            return
        }
        publications.removeValue(forKey: endpoint)
        containers.removeValue(forKey: endpoint)
        // Remove selfLinks from publication.
        publication.links.removeAll(where: { $0.rels.contains("self") })
        log(.info, "Publication at \(endpoint) has been successfully removed.")
    }
    
    /// Remove all publication from the server.
    public func removeAll() {
        for (endpoint, publication) in publications {
            // Remove selfLinks from publication.
            publication.links.removeAll(where: { $0.rels.contains("self") })
            
            log(.info, "Publication at \(endpoint) has been successfully removed.")
        }
        
        publications.removeAll()
        containers.removeAll()
    }
    
    
    /// MARK: ResourcesServer
    
    /// Mapping between the served path and the local file URL of resources.
    private var resources: [String: URL] = [:]
    
    @discardableResult
    public func serve(_ url: URL, at path: String) throws -> URL {
        guard let baseURL = baseURL else {
            throw ResourcesServerError.serverFailure
        }
        var path = path
        if !path.hasPrefix("/") {
            path = "/\(path)"
        }
        guard !path.isEmpty else {
            throw ResourcesServerError.invalidPath
        }
        guard url.isFileURL,
            FileManager.default.fileExists(atPath: url.path) else
        {
            throw ResourcesServerError.fileNotFound
        }
        
        if resources[path] == nil {
            webServer.addHandler(
                forMethod: "GET",
                pathRegex: "\(path)(/.*)?",
                request: GCDWebServerRequest.self,
                processBlock: resourceHandler
            )
        }
        
        resources[path] = url
        
        return baseURL.appendingPathComponent(String(path.dropFirst()))
    }
    
    private func resourceHandler(_ request: GCDWebServerRequest?) -> GCDWebServerResponse? {
        guard let request = request else {
            return nil
        }
        var path = request.path
        let paths = resources.keys.sorted().reversed()
        guard let basePath = paths.first(where: { path.hasPrefix($0) }),
            var file = resources[basePath] else
        {
            return GCDWebServerResponse(statusCode: 404)
        }
        path = String(path.dropFirst(basePath.count + 1))
        file.appendPathComponent(path)
        
        guard let data = try? Data(contentsOf: file) else {
            return GCDWebServerResponse(statusCode: 404)
        }
        
        let contentType = DocumentTypes.contentType(for: file) ?? "application/octet-stream"

//        log(.debug, "Serve resource `\(path)` (\(contentType))")
        return GCDWebServerDataResponse(data: data, contentType: contentType)
    }
    
}

