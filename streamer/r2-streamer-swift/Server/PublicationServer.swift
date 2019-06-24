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

import CoreServices
import Foundation
import R2Shared
#if COCOAPODS
import GCDWebServer
#else
import GCDWebServers
#endif

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
    // Dictionnary of the (container, publication) tuples keyed by endpoints.
    public var pubBoxes = [String: PubBox]()
    
    // Computed properties.
    
    /// The running HTTP server listening port.
    public var port: UInt? {
        get { return webServer.port }
    }
    
    /// The base URL of the server
    public var baseURL: URL? {
        get { return webServer.serverURL }
    }
    
    /// Returns all the `Publications`, sorted by the container's last modification date.
    /// FIXME: the sorting should be done on the test app's side, to present the library according to the user's criteria.
    public var publications: [Publication] {
        return pubBoxes.values
            .sorted { $0.associatedContainer.modificationDate > $1.associatedContainer.modificationDate }
            .map { $0.publication }
    }
    
    /// Returns all the `Containers` as an array.
    public var containers: [Container] {
        return pubBoxes.values.map { $0.associatedContainer }
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
    
    internal func startWebServer() -> Bool {
        // with port 0, a random port is used each time.
        let port = 0
        do {
            // TODO: Check if we can use unix socket instead of tcp.
            //       Check if it's supported by WKWebView first.
            try webServer.start(options: [GCDWebServerOption_Port: port,
                                          GCDWebServerOption_BindToLocalhost: true])
        } catch {
            log(.error, "Failed to start the HTTP server: \(error)")
            return false
        }
        return true
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
    
    /// Add a publication to the server. Also add it to the `pubBoxes`
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
        guard pubBoxes[endpoint] == nil else {
            log(.error, "\(endpoint) is already in use.")
            throw PublicationServerError.usedEndpoint
        }
        guard let baseURL = baseURL else {
            log(.error, "Base URL is nil.")
            throw PublicationServerError.nilBaseURL
        }
        
        // Add the self link to the publication.
        publication.addSelfLink(endpoint: endpoint, for: baseURL)
        // Add the Publication to the publication boxes dictionnary.
        let pubBox = PubBox(publication: publication,
                            associatedContainer: container)
        
        pubBoxes[endpoint] = pubBox
        
        /// Add resources handler.
        do {
            try addResourcesHandler(for: pubBox, at: endpoint)
        } catch {
            throw PublicationServerError.fetcher(underlyingError: error)
        }
        /// Add manifest handler.
        addManifestHandler(for: pubBox, at: endpoint)
        
        log(.info, "Publication at \(endpoint) has been successfully added.")
    }
    
    fileprivate func addResourcesHandler(for pubBox: PubBox, at endpoint: String) throws {
        let publication = pubBox.publication
        let container = pubBox.associatedContainer
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
    
    fileprivate func addManifestHandler(for pubBox: PubBox, at endpoint: String) {
        let publication = pubBox.publication
        let container = pubBox.associatedContainer
        
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
            processBlock: manifestHandler)
        
    }
    
    public func remove(_ publication: Publication) {
        for pubBox in pubBoxes {
            if pubBox.value.publication.metadata.identifier == publication.metadata.identifier,
                let index = pubBoxes.index(forKey: pubBox.key)
            {
                pubBoxes.remove(at: index)
                // Remove selfLinks from publication.
                publication.links = publication.links.filter { !$0.rels.contains("self") }
                break
            }
        }
    }
    
    /// Remove a publication from the server.
    ///
    /// - Parameter endpoint: The URI postfix of the ressource.
    public func remove(at endpoint: String) {
        guard let pubBox = pubBoxes[endpoint] else {
            log(.warning, "Nothing at endpoint \(endpoint).")
            return
        }
        // Remove self link from publication.
        pubBox.publication.links = pubBox.publication.links.filter { !$0.rels.contains("self") }
        // Remove the pubBox from the array.
        pubBoxes[endpoint] = nil
        log(.info, "Publication at \(endpoint) has been successfully removed.")
    }
    
    /// Remove all publication from the server.
    public func removeAll() {
        for pubBox in pubBoxes {
            if let index = pubBoxes.index(forKey: pubBox.key)
            {
                pubBoxes.remove(at: index)
                log(.info, "Publication at \(pubBox.key) has been successfully removed.")
            }
        }
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
        
        let contentType: String = {
            guard let extUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, file.pathExtension as CFString, nil)?.takeUnretainedValue(),
                let mimetype = UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)?.takeRetainedValue() as String? else
            {
                return "application/octet-stream"
            }
            return mimetype
        }()
        
//        log(.debug, "Serve resource `\(path)` (\(contentType))")
        return GCDWebServerDataResponse(data: data, contentType: contentType)
    }
    
}

