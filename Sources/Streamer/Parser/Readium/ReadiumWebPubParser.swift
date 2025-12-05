//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public enum ReadiumWebPubParserError: Error {
    case parseFailure(url: URL, Error?)
    case missingFile(path: String)
}

/// Parser for a Readium Web Publication (packaged, or as a manifest).
public class ReadiumWebPubParser: PublicationParser, Loggable {
    public enum Error: Swift.Error {
        case manifestNotFound
        case invalidManifest
    }

    private let pdfFactory: PDFDocumentFactory?
    private let httpClient: HTTPClient
    private let epubReflowablePositionsStrategy: EPUBPositionsService.ReflowableStrategy

    /// - Parameter epubReflowablePositionsStrategy: Strategy used to calculate
    ///   the number of positions in a reflowable resource of a web publication
    ///   conforming to the EPUB profile.
    public init(pdfFactory: PDFDocumentFactory?, httpClient: HTTPClient, epubReflowablePositionsStrategy: EPUBPositionsService.ReflowableStrategy = .recommended) {
        self.pdfFactory = pdfFactory
        self.httpClient = httpClient
        self.epubReflowablePositionsStrategy = epubReflowablePositionsStrategy
    }

    public func parse(
        asset: Asset,
        warnings: (any WarningLogger)?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        switch asset {
        case let .resource(asset):
            return await parse(resource: asset.resource, format: asset.format.specifications, warnings: warnings)
        case let .container(asset):
            return await parse(container: asset.container, format: asset.format.specifications, warnings: warnings)
        }
    }

    private func parse(
        resource: Resource,
        format: FormatSpecifications,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard format.conformsTo(.rwpm) else {
            return .failure(.formatNotSupported)
        }

        return await resource.readAsRWPM(warnings: warnings)
            .flatMap { manifest in
                let baseURL = manifest.baseURL
                if baseURL == nil {
                    warnings?.log(RWPMWarning(message: "No valid self link found in the manifest", severity: .moderate))
                }

                return .success(CompositeContainer(
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
                ))
            }
            .mapError { .reading($0) }
            .asyncFlatMap { container in
                await parse(
                    container: container,
                    format: FormatSpecifications(.rpf),
                    warnings: warnings
                )
            }
    }

    private func parse(
        container: Container,
        format: FormatSpecifications,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard format.conformsTo(.rpf) else {
            return .failure(.formatNotSupported)
        }

        guard let manifestResource = container[RelativeURL(path: "manifest.json")!] else {
            return .failure(.reading(.decoding("Cannot find a manifest.json file in the RPF package.")))
        }

        return await manifestResource.readAsRWPM(warnings: warnings)
            .flatMap(checkProfileRequirements(of:))
            .map { manifest in
                var manifest = manifest

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
                    })
                )
            }
            .mapError { .reading($0) }
    }

    private func checkProfileRequirements(of manifest: Manifest) -> Result<Manifest, ReadError> {
        guard !manifest.readingOrder.isEmpty else {
            return .failure(.decoding("The manifest reading order is empty"))
        }

        if manifest.conforms(to: .pdf) {
            guard manifest.readingOrder.allMatchingMediaType(.pdf) else {
                return .failure(.decoding("The publication does not conform to the PDF profile specification"))
            }
        } else if manifest.conforms(to: .audiobook) {
            guard manifest.readingOrder.allAreAudio else {
                return .failure(.decoding("The publication does not conform to the Audiobook profile specification"))
            }
        }

        return .success(manifest)
    }
}

private extension Streamable {
    /// Reads the whole content as a Readium Web Pub Manifest.
    func readAsRWPM(warnings: WarningLogger?) async -> ReadResult<Manifest> {
        await readAsJSON().flatMap {
            do {
                return try .success(Manifest(json: $0, warnings: warnings))
            } catch {
                return .failure(.decoding(error))
            }
        }
    }
}

/// Warning raised when parsing a RWPM.
public struct RWPMWarning: Warning {
    public let message: String
    public let severity: WarningSeverityLevel

    public var tag: String { "rwpm" }
}
