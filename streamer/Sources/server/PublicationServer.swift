//
//  PublicationServer.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import GCDWebServers

extension PublicationServer: Loggable {}

/// Errors thrown by the `PublicationServer`.
///
/// - parser: An error thrown by the Parser.
/// - fetcher: An error thrown by the Fetcher.
/// - nilBaseUrl: <#nilBaseUrl description#>
/// - usedEndpoint: <#usedEndpoint description#>
public enum PublicationServerError: Error{
    case parser(underlyingError: Error)
    case fetcher(underlyingError: Error)
    case nilBaseUrl
    case usedEndpoint
}

/// `Publication` and the associated `Container`.
public typealias PubBox = (publication: Publication, associatedContainer: Container)

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

    /// Return all the `Publications` sorted by title asc.
    public var publications: [Publication] {
        get {
            let publications = pubBoxes.values.flatMap({ $0.publication })

            return publications.sorted(by: { $0.metadata.title < $1.metadata.title })
        }
    }

    /// Return all the `Container` as an array.
    public var containers: [Container] {
        get { return  pubBoxes.values.flatMap({ $0.associatedContainer }) }
    }

    // MARK: - Public methods

    public init?() {
        #if DEBUG
            let port = 8080

            GCDWebServer.setLogLevel(2)
        #else
            // Default: random port
            let port = 0

            GCDWebServer.setLogLevel(3)
        #endif
        webServer = GCDWebServer()
        do {
            // TODO: Check if we can use unix socket instead of tcp.
            //       Check if it's supported by WKWebView first.
            try webServer.start(options: [GCDWebServerOption_Port: port,
                                          GCDWebServerOption_BindToLocalhost: true])
        } catch {
            log(level: .error, "Failed to start the HTTP server.")
            logValue(level: .error, error)
            return nil
        }

        webServer.addHandler(forMethod: "GET",
                             pathRegex: "/Reflow.css", request: GCDWebServerRequest.self, processBlock:  { request in
//                                request?.path
                                let styleUrl = Bundle(for: ContentFiltersEpub.self).url(forResource: "Reflow", withExtension: "css")
                                let data = try! Data.init(contentsOf: styleUrl!)

                                return GCDWebServerDataResponse(data: data, contentType: "text/css")
        })
    }

    // TODO: Github issue #3
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
        let fetcher: Fetcher

        guard pubBoxes[endpoint] == nil else {
            log(level: .error, "\(endpoint) is already in use.")
            throw PublicationServerError.usedEndpoint
        }
        guard let baseUrl = baseUrl else {
            log(level: .error, "Base URL is nil.")
            throw PublicationServerError.nilBaseUrl
        }

        // Add the self link to the publication.
        publication.addSelfLink(endpoint: endpoint, for: baseUrl)
        // Add the Publication to the publication boxes dictionnary.
        pubBoxes[endpoint] = (publication, container)

        // Initialize the Fetcher.
        do {
            fetcher = try Fetcher(publication: publication, container: container)
        } catch {
            log(level: .error, "Fetcher initialisation failed.")
            throw PublicationServerError.fetcher(underlyingError: error)
        }

        /// Webserver HTTP GET ressources request handler.
        func ressourcesHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            let response: GCDWebServerResponse

            guard let request = request else {
                log(level: .error, "The request received is nil.")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            guard let path = request.path else {
                log(level: .error, "The request's path to the ressource is empty.")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            // Remove the prefix from the URI.
            let relativePath = path.substring(from: path.index(endpoint.endIndex, offsetBy: 2))
            let resource = publication.resource(withRelativePath: relativePath)
            let contentType = resource?.typeLink ?? "application/octet-stream"
            // Get a data input stream from the fetcher.
            do {
                let dataStream = try fetcher.dataStream(forRelativePath: relativePath)
                let range = request.hasByteRange() ? request.byteRange : nil

                response = WebServerResourceResponse(inputStream: dataStream,
                                                     range: range,
                                                     contentType: contentType)
            } catch FetcherError.missingFile {
                log(level: .error, "File not found, couldn't create stream.")
                response = GCDWebServerErrorResponse(statusCode: 404)
            } catch FetcherError.container {
                log(level: .error, "Error while getting data stream from container.")
                response = GCDWebServerErrorResponse(statusCode: 500)
            } catch {
                logValue(level: .error, error)
                response = GCDWebServerErrorResponse(statusCode: 500)
            }
            return response
        }
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "/\(endpoint)/.*",
            request: GCDWebServerRequest.self,
            processBlock: ressourcesHandler)

        /// The webserver handler to process the HTTP GET
        func manifestHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            let manifestJSON = publication.toJSONString()
            let manifestData = manifestJSON?.data(using: .utf8)
            let type = "application/webpub+json; charset=utf-8"

            return GCDWebServerDataResponse(data: manifestData, contentType: type)
        }
        webServer.addHandler(
            forMethod: "GET",
            pathRegex: "/\(endpoint)/manifest.json",
            request: GCDWebServerRequest.self,
            processBlock: manifestHandler)

        // FIXME: Add the handler for the resources OPTIONS
        //         webServer.addHandler(
        //         forMethod: "OPTIONS",
        //         pathRegex: "/\(endpoint)/.*",
        //         request: GCDWebServerRequest.self,
        //         processBlock: { request in
        //
        //         guard let path = request?.path else {
        //         Log.error?.message("no path in options request")
        //         return GCDWebServerErrorResponse(statusCode: 500)
        //         }
        //
        //         Log.debug?.message("options request \(path)")
        //
        //         return GCDWebServerDataResponse()
        //         })

        log(level: .info, "Publication at \(endpoint) has been successfully added.")
    }

    public func remove(_ publication: Publication) {
        for pubBox in pubBoxes {
            if pubBox.value.publication.metadata.identifier == publication.metadata.identifier,
                let index = pubBoxes.index(forKey: pubBox.key)
            {
                pubBoxes.remove(at: index)
                // Remove selfLinks from publication.
                publication.links = publication.links.filter { !$0.rel.contains("self") }
                break
            }
        }
    }

//    /// Remove a publication from the server.
//    ///
//    /// - Parameter endpoint: The PublicationIdentifier of the Publication to remove.
//    public func remove(publicationIdentifier: String) {
//        var keyToRemove: String? = nil
//
//        // Find the publication key in pubBoxes.
//        for pubBoxe in pubBoxes {
//            if pubBoxe.value.publication.metadata.identifier == publicationIdentifier {
//                keyToRemove = pubBoxe.key
//                break
//            }
//        }
//        // Remove the publication from the publicationServer served publications.
//        if keyToRemove != nil {
//            remove(at: keyToRemove!)
//        }
//    }

    /// Remove a publication from the server.
    ///
    /// - Parameter endpoint: The URI postfix of the ressource.
    public func remove(at endpoint: String) {
        guard let pubBox = pubBoxes[endpoint] else {
            log(level: .warning, "Nothing at endpoint \(endpoint).")
            return
        }
        // Remove self link from publication.
        pubBox.publication.links = pubBox.publication.links.filter { !$0.rel.contains("self") }
        // Remove the pubBox from the array.
        pubBoxes[endpoint] = nil
        log(level: .info, "Publication at \(endpoint) has been successfully removed.")
    }
}
