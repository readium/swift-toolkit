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
    case nilBaseUrl
    case usedEndpoint
}

/// The HTTP server for the publication's manifests and assets. Serves Epubs.
public class PublicationServer {
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
    public var baseUrl: URL? {
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
        func styleResourcesHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            guard let request = request else {
                return GCDWebServerResponse(statusCode: 404)
            }
            let relativePath = request.path.deletingLastPathComponent
            let resourceName = (request.path as NSString).deletingPathExtension.lastPathComponent

            if let styleUrl = Bundle(for: ContentFiltersEpub.self).url(forResource: resourceName, withExtension: "css", subdirectory: relativePath),
                let data = try? Data.init(contentsOf: styleUrl)
            {
                let response = GCDWebServerDataResponse(data: data, contentType: "text/css")

                return response
            } else {
                return GCDWebServerResponse(statusCode: 404)
            }
        }
        /// Handler for Style resources.
        webServer.addHandler(forMethod: "GET",
                             pathRegex: "/styles/*",
                             request: GCDWebServerRequest.self,
                             processBlock: styleResourcesHandler)

        func scriptResourcesHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            guard let request = request else {
                return GCDWebServerResponse(statusCode: 404)
            }
            let relativePath = request.path.deletingLastPathComponent
            let resourceName = (request.path as NSString).deletingPathExtension.lastPathComponent

            if let scriptUrl = Bundle(for: ContentFiltersEpub.self).url(forResource: resourceName, withExtension: "js", subdirectory: relativePath),
                let data = try? Data.init(contentsOf: scriptUrl)
            {
                let response = GCDWebServerDataResponse(data: data, contentType: "text/javascript")

                return response
            } else {
                return GCDWebServerResponse(statusCode: 404)
            }
        }
        /// Handler for JS resources.
        webServer.addHandler(forMethod: "GET",
                             pathRegex: "/scripts/*",
                             request: GCDWebServerRequest.self,
                             processBlock: scriptResourcesHandler)
        
        func fontResourcesHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            guard let request = request else {
                return GCDWebServerResponse(statusCode: 404)
            }
            let relativePath = request.path.deletingLastPathComponent
            let resourceName = (request.path as NSString).deletingPathExtension.lastPathComponent
            
            if let fontUrl = Bundle(for: ContentFiltersEpub.self).url(forResource: resourceName, withExtension: "otf", subdirectory: relativePath),
                let data = try? Data.init(contentsOf: fontUrl)
            {
                let response = GCDWebServerDataResponse(data: data, contentType: "font/opentype")
                
                return response
            } else {
                return GCDWebServerResponse(statusCode: 404)
            }
        }
        /// Handler for Font resources.
        webServer.addHandler(forMethod: "GET",
                             pathRegex: "/fonts/*",
                             request: GCDWebServerRequest.self,
                             processBlock: fontResourcesHandler)
        
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
        guard let baseUrl = baseUrl else {
            log(.error, "Base URL is nil.")
            throw PublicationServerError.nilBaseUrl
        }

        // Add the self link to the publication.
        publication.addSelfLink(endpoint: endpoint, for: baseUrl)
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
}
