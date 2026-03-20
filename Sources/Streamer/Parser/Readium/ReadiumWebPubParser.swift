//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public enum ReadiumWebPubParserError: Error, Sendable {
    case parseFailure(url: URL, Error?)
    case missingFile(path: String)
}

/// Parser for a Readium Web Publication (packaged, or as a manifest).
public final class ReadiumWebPubParser: PublicationParser, Loggable {
    public enum Error: Swift.Error, Sendable {
        case manifestNotFound
        case invalidManifest
    }

    private let pdfFactory: PDFDocumentFactory?
    private let httpClient: HTTPClient
    private let epubReflowablePositionsStrategy: EPUBPositionsService.ReflowableStrategy

    /// - Parameters:
    ///   - pdfFactory: Factory used to open PDF documents, if available.
    ///   - httpClient: The HTTP client used to fetch remote resources.
    ///   - epubReflowablePositionsStrategy: Strategy used to calculate
    ///     the number of positions in a reflowable resource of a web publication
    ///     conforming to the EPUB profile.
    public init(pdfFactory: PDFDocumentFactory?, httpClient: HTTPClient, epubReflowablePositionsStrategy: EPUBPositionsService.ReflowableStrategy = .recommended) {
        self.pdfFactory = pdfFactory
        self.httpClient = httpClient
        self.epubReflowablePositionsStrategy = epubReflowablePositionsStrategy
    }

    public func parse(
        asset: Asset,
        warnings: (any WarningLogger)?
    ) async throws(PublicationParseError) -> Publication.Builder {
        switch asset {
        case let .resource(asset):
            return try await parse(resource: asset.resource, format: asset.format.specifications, warnings: warnings)
        case let .container(asset):
            return try await parse(container: asset.container, format: asset.format.specifications, warnings: warnings)
        }
    }

    private func parse(
        resource: Resource,
        format: FormatSpecifications,
        warnings: WarningLogger?
    ) async throws(PublicationParseError) -> Publication.Builder {
        guard format.conformsTo(.rwpm) else {
            throw .formatNotSupported
        }

        let container: Container
        do {
            let manifest = try await resource.read()
                .asRWPM(warnings: warnings)

            let baseURL = manifest.baseURL
            if baseURL == nil {
                warnings?.log(RWPMWarning(message: "No valid self link found in the manifest", severity: .moderate))
            }

            container = CompositeContainer(
                SingleResourceContainer(
                    resource: resource,
                    at: AnyURL(string: "manifest.json")!
                ),
                HTTPContainer(
                    client: httpClient,
                    baseURL: baseURL,
                    entries: Set(
                        (manifest.readingOrder + manifest.resources)
                            .map { $0.url() }
                    )
                )
            )
        } catch {
            throw .reading(error)
        }

        return try await parse(
            container: container,
            format: FormatSpecifications(.rpf),
            warnings: warnings
        )
    }

    private func parse(
        container: Container,
        format: FormatSpecifications,
        warnings: WarningLogger?
    ) async throws(PublicationParseError) -> Publication.Builder {
        guard format.conformsTo(.rpf) else {
            throw .formatNotSupported
        }

        guard let manifestResource = container[RelativeURL(path: "manifest.json")!] else {
            throw .reading(.decoding("Cannot find a manifest.json file in the RPF package."))
        }

        do {
            var manifest = try await manifestResource.read()
                .asRWPM(warnings: warnings)
            manifest = try checkProfileRequirements(of: manifest)

            // Remove any self link as it is a packaged publication. It
            // might be packaged from a streamed manifest which would cause
            // issues when serving the relative reading order resources.
            manifest.links = manifest.links.filter { !$0.rels.contains(.self) }

            return Publication.Builder(
                manifest: manifest,
                container: container,
                servicesBuilder: PublicationServicesBuilder(setup: {
                    if manifest.conforms(to: .epub) {
                        $0.setPositionsServiceFactory(EPUBPositionsService.makeFactory(reflowableStrategy: epubReflowablePositionsStrategy))

                    } else if manifest.conforms(to: .divina) {
                        $0.setPositionsServiceFactory(PerResourcePositionsService.makeFactory(fallbackMediaType: MediaType("image/*")!))

                    } else if manifest.conforms(to: .audiobook) {
                        $0.setLocatorServiceFactory(AudioLocatorService.makeFactory())

                    } else if manifest.conforms(to: .pdf), format.conformsTo(.lcp), let pdfFactory = pdfFactory {
                        $0.setTableOfContentsServiceFactory(LCPDFTableOfContentsService.makeFactory(pdfFactory: pdfFactory))
                        $0.setPositionsServiceFactory(LCPDFPositionsService.makeFactory(pdfFactory: pdfFactory))
                    }

                    // FIXME: WebPositionsService from Kotlin?

                    if manifest.readingOrder.allAreHTML {
                        $0.setSearchServiceFactory(StringSearchService.makeFactory())
                        $0.setContentServiceFactory(DefaultContentService.makeFactory(
                            resourceContentIteratorFactories: [
                                HTMLResourceContentIterator.Factory(),
                            ]
                        ))
                    }

                    $0.setGuidedNavigationServiceFactory(ReadiumGuidedNavigationService.makeFactory())
                })
            )
        } catch {
            throw .reading(error)
        }
    }

    private func checkProfileRequirements(of manifest: Manifest) throws(ReadError) -> Manifest {
        guard !manifest.readingOrder.isEmpty else {
            throw .decoding("The manifest reading order is empty")
        }

        if manifest.conforms(to: .pdf) {
            guard manifest.readingOrder.allMatchingMediaType(.pdf) else {
                throw .decoding("The publication does not conform to the PDF profile specification")
            }
        } else if manifest.conforms(to: .audiobook) {
            guard manifest.readingOrder.allAreAudio else {
                throw .decoding("The publication does not conform to the Audiobook profile specification")
            }
        }

        return manifest
    }
}

private extension Data {
    /// Decodes the data as a Readium Web Pub Manifest.
    func asRWPM(warnings: WarningLogger?) throws(ReadError) -> Manifest {
        let json = try asJSONObjectValue()
        do {
            guard let manifest = try Manifest(json: json, warnings: warnings) else {
                throw ReadError.decoding("Failed to decode Manifest from JSON.")
            }
            return manifest
        } catch let error as ReadError {
            throw error
        } catch {
            throw .decoding(error)
        }
    }
}

/// Warning raised when parsing a RWPM.
public struct RWPMWarning: Warning, Sendable {
    public let message: String
    public let severity: WarningSeverityLevel

    public var tag: String {
        "rwpm"
    }
}
