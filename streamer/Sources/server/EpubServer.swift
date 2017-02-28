//
//  EpubServer.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import GCDWebServers

/// Errors thrown during the serving of the EPUB
///
/// - epubParser: An error thrown by the EpubParser
/// - epubFetcher: An error thrown by the EpubFetcher
public enum EpubServerError: Error {
    case epubParser(underlayingError: Error)
    case epubFetcher(underlayingError: Error)
}

/// The HTTP server for the publication's manifests and assets
open class EpubServer {
    /// The HTTP server
    var webServer: GCDWebServer
    /// The dictionary of EPUB containers keyed by prefix
    var containers: [String: Container] = [:]
    /// The dictionaty of publications keyed by prefix
    var publications: [String: Publication] = [:]
    /// The running HTTP server listening port
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

            GCDWebServer.setLogLevel(0)
        #else
            // Default: random port
            let port = 0

            GCDWebServer.setLogLevel(3)
        #endif

        webServer = GCDWebServer()
        do {
            try webServer.start(options: [GCDWebServerOption_Port: port,
                                          GCDWebServerOption_BindToLocalhost: true])
        } catch {
            NSLog("Failed to start the HTTP server: \(error)")
            return nil
        }
    }


    /// Add an EPUB container to the list of EPUBS being served.
    ///
    /// - Parameters:
    ///   - container: The EPUB container of the publication
    ///   - endpoint: The URI prefix to use to fetch assets from the publication
    ///               `/{prefix}/{assetRelativePath}`
    /// - Throws: `EpubServerError.epubParser`
    public func addEpub(container: Container, withEndpoint endpoint: String) throws {
        let parser: EpubParser
        let publication: Publication
        let fetcher: EpubFetcher

        guard containers[endpoint] == nil else {
            return
        }
        // Parser + Publication initialisation
        do {
            parser = try EpubParser(container: container)
            publication = try parser.parse()
        } catch {
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
            throw EpubServerError.epubFetcher(underlayingError: error)
        }
        /// Webserver HTTP GET ressources request handler
        func ressourcesHandler(request: GCDWebServerRequest?) -> GCDWebServerResponse? {
            let response: GCDWebServerResponse
            let relativePath: String
            let resource: Link?
            let contentType: String

            guard let request = request else {
                NSLog("No request (nil)")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            guard let path = request.path else {
                NSLog("no path in request")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            NSLog("request \(path)")
            // Remove the prefix from the URI
            relativePath = path.substring(from: path.index(endpoint.endIndex, offsetBy: 3))
            resource = publication.resource(withRelativePath: relativePath)
            contentType = resource?.typeLink ?? "application/octet-stream"
            // Get a data input stream from the fetcher
            do {
                let dataStream = try fetcher.dataStream(forRelativePath: relativePath)
                let range = request.hasByteRange() ? request.byteRange : nil
                let r = WebServerResourceResponse(inputStream: dataStream,
                                                  range: range,
                                                  contentType: contentType)
                response = r
            } catch EpubFetcherError.missingFile {
                NSLog("Error file not found, couldn't create stream")
                response = GCDWebServerErrorResponse(statusCode: 404)
            } catch EpubFetcherError.container {
                NSLog("Error while getting data stream from container")
                response = GCDWebServerErrorResponse(statusCode: 500)
            } catch {
                NSLog("Error \(error) occured")
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
        //         NSLog("no path in options request")
        //         return GCDWebServerErrorResponse(statusCode: 500)
        //         }
        //
        //         NSLog("options request \(path)")
        //
        //         return GCDWebServerDataResponse()
        //         })
    }

    /// Remove an EPUB container from the server.
    ///
    /// - Parameter endpoint: The URI postfix of the ressource
    public func removeEpub(at endpoint: String) {
        guard containers[endpoint] != nil else {
            return
        }
        containers[endpoint] = nil
        publications[endpoint] = nil
        // TOFO: Remove associated handlers
        // Only method available with GCDWebServer is
        //webServer.removeAllHandlers()

    }

    // MARK: - Internal methods

    /// Append a link to self in the given Publication links
    ///
    /// - Parameters:
    ///   - publication: The targeted publication.
    ///   - endPoint: The URI prefix to use to fetch assets from the publication.
    internal func addSelfLinkTo(publication: Publication, endpoint: String) {
        let publicationURL: URL
        let link: Link
        let manifestPath = "\(endpoint)/manifest.json"

        guard let baseURL = baseURL else {
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
