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
    case epubParser(underlayingError: Error)
    case epubFetcher(underlayingError: Error)
}

/// The HTTP server for the publication's manifests and assets. Serves Epubs.
open class EpubServer {

    /// The HTTP server
    var webServer: GCDWebServer

    let parser = EpubParser()

    // FIXME: probably get rid of the server serving multiple epub at a given time
    //          better to implement indexing for multibook search etc
    /// The dictionary of EPUB containers keyed by prefix.
    var containers: [String: Container] = [:]

    /// The dictionaty of publications keyed by prefix.
    var publications: [String: Publication] = [:]

    /// The running HTTP server listening port.
    public var port: UInt? {
        get { return webServer.port }
    }

    /// The base URL of the server
    public var baseURL: URL? {
        get { return webServer.serverURL }
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
    /// Add an EPUB container to the list of EPUBS being served.
    ///
    /// - Parameters:
    ///   - container: The EPUB container of the publication
    ///   - endpoint: The URI prefix to use to fetch assets from the publication
    ///               `/{prefix}/{assetRelativePath}`
    /// - Throws: `EpubServerError.epubParser`
    public func addEpub(container: inout Container, withEndpoint endpoint: String) throws {
        let publication: Publication
        let fetcher: EpubFetcher

        guard containers[endpoint] == nil else {
            log(level: .warning, "\(endpoint) is already in use.")
            return
        }
        // Publication initialisation
        do {
            publication = try parser.parse(container: &container)
        } catch {
            log(level: .error, "The publication parsing failed.")
            throw EpubServerError.epubParser(underlayingError: error)
        }
        addSelfLinkTo(publication: publication, endpoint: endpoint)
        // FIXME: Are these dictionaries really necessary?
        containers[endpoint] = container
        publications[endpoint] = publication
        // Initialize the Fetcher
        do {
            fetcher = try EpubFetcher(publication: publication, container: container)
        } catch {
            log(level: .error, "Fetcher initialisation failed.")
            throw EpubServerError.epubFetcher(underlayingError: error)
        }

        /// Webserver HTTP GET ressources request handler
        func ressourcesHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            let response: GCDWebServerResponse
            let relativePath: String
            let resource: Link?
            let contentType: String

            guard let request = request else {
                log(level: .error, "The request received is nil.")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            guard let path = request.path else {
                log(level: .error, "The request's path to the ressource is empty.")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            logValue(level: .debug, path)
            // Remove the prefix from the URI
            relativePath = path.substring(from: path.index(endpoint.endIndex, offsetBy: 3))
            resource = publication.resource(withRelativePath: relativePath)
            contentType = resource?.typeLink ?? "application/octet-stream"
            // Get a data input stream from the fetcher
            do {
                let dataStream = try fetcher.dataStream(forRelativePath: relativePath)
                let range = request.hasByteRange() ? request.byteRange : nil

                response = WebServerResourceResponse(inputStream: dataStream,
                                                     range: range,
                                                     contentType: contentType)
            } catch EpubFetcherError.missingFile {
                log(level: .error, "File not found, couldn't create stream.")
                response = GCDWebServerErrorResponse(statusCode: 404)
            } catch EpubFetcherError.container {
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
        guard containers[endpoint] != nil else {
            log(level: .error, "Container endpoint is nil.")
            return
        }
        containers[endpoint] = nil
        publications[endpoint] = nil
        // TODO: Remove associated handlers
        // Only method available with GCDWebServer is
        //webServer.removeAllHandlers()
        log(level: .info, "Epub at \(endpoint) has been successfully removed.")
    }

    // MARK: - Internal methods

    /// Append a link to self in the given Publication links.
    ///
    /// - Parameters:
    ///   - publication: The targeted publication.
    ///   - endPoint: The URI prefix to use to fetch assets from the publication.
    internal func addSelfLinkTo(publication: Publication, endpoint: String) {
        let publicationURL: URL
        let link: Link
        let manifestPath = "\(endpoint)/manifest.json"

        guard let baseURL = baseURL else {
            log(level: .warning, "Base URL is nil.")
            return
        }
        publicationURL = baseURL.appendingPathComponent(manifestPath,
                                                        isDirectory: false)
        link = Link(href: publicationURL.absoluteString,
                    typeLink: "application/webpub+json",
                    rel: "self")
        publication.links.append(link)
    }
    
}
