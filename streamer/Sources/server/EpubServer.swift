//
//  EpubServer.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import GCDWebServers

extension EpubServer: Loggable {}

/// Errors thrown by the `EpubServer`.
///
/// - epubParser: An error thrown by the EpubParser.
/// - epubFetcher: An error thrown by the EpubFetcher.
public enum EpubServerError: Error{
    case epubParser(underlyingError: Error)
    case epubFetcher(underlyingError: Error)
    case nilBaseUrl
    case usedEndpoint
}

/// `Publication` and the associated `Container`.
public typealias Epub = (publication: Publication, associatedContainer: Container)

/// The HTTP server for the publication's manifests and assets. Serves Epubs.
open class EpubServer {

    // TODO: declare an interface, decouple the webserver. ? Not prioritary.
    /// The HTTP server.
    var webServer: GCDWebServer
    // Dictionnary of the (container, publication) tuples keyed by endpoints.
    var epubs = [String: Epub]()

    // Computed properties.

    /// The running HTTP server listening port.
    public var port: UInt? {
        get { return webServer.port }
    }

    /// The base URL of the server
    public var baseUrl: URL? {
        get { return webServer.serverURL }
    }

    /// Return all the `Publications` sorted by title asc. Sugar on top of `epubs`.
    public var publications: [Publication] {
        get {
            let publications = epubs.values.flatMap({ $0.publication })

            return publications.sorted(by: { $0.metadata.title < $1.metadata.title })
        }
    }

    /// Return all the `Container` as an array. Sugar on top of `epubs`.
    public var containers: [Container] {
        get { return  epubs.values.flatMap({ $0.associatedContainer }) }
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
    }

    // TODO: Github issue #3
    /// Add an Epub to the server `Epubs`.
    ///
    /// - Parameters:
    ///   - container: The EPUB container of the publication
    ///   - endpoint: The URI prefix to use to fetch assets from the publication
    ///               `/{prefix}/{assetRelativePath}`
    /// - Throws: `throw EpubServerError.usedEndpoint`,
    ///           `EpubServerError.nilBaseUrl`,
    ///           `EpubServerError.epubFetcher`.
    public func add(_ publication: Publication,
                    with container: Container,
                    at endpoint: String) throws {
        let fetcher: Fetcher

        guard epubs[endpoint] == nil else {
            log(level: .error, "\(endpoint) is already in use.")
            throw EpubServerError.usedEndpoint
        }
        guard let baseUrl = baseUrl else {
            log(level: .error, "Base URL is nil.")
            throw EpubServerError.nilBaseUrl
        }

        // Add the self link to the publication.
        publication.addSelfLink(endpoint: endpoint, for: baseUrl)
        // Add the Epub to the epub dictionnary.
        epubs[endpoint] = (publication, container)

        // Initialize the Fetcher
        do {
            fetcher = try Fetcher(publication: publication, container: container)
        } catch {
            log(level: .error, "Fetcher initialisation failed.")
            throw EpubServerError.epubFetcher(underlyingError: error)
        }

        /// Webserver HTTP GET ressources request handler
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
            // Remove the prefix from the URI
            let relativePath = path.substring(from: path.index(endpoint.endIndex, offsetBy: 3))
            let resource = publication.resource(withRelativePath: relativePath)
            let contentType = resource?.typeLink ?? "application/octet-stream"
            // Get a data input stream from the fetcher
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
        log(level: .info, "Epub at \(endpoint) has been successfully added.")
    }

    /// Remove an EPUB container from the server.
    ///
    /// - Parameter endpoint: The URI postfix of the ressource.
    public func removeEpub(at endpoint: String) {
        guard epubs[endpoint] != nil else {
            log(level: .warning, "Nothing at endpoint \(endpoint).")
            return
        }
        epubs[endpoint] = nil
        log(level: .info, "Epub at \(endpoint) has been successfully removed.")
    }
}
