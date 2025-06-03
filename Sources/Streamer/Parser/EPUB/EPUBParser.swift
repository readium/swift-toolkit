//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

/// Epub related constants.
private enum EPUBConstant {
    /// Media Overlays URL.
    static let mediaOverlayURL = "media-overlay?resource="
}

/// Errors thrown during the parsing of the EPUB
///
/// - wrongMimeType: The mimetype file is missing or its content differs from
///                 "application/epub+zip" (expected).
/// - missingFile: A file is missing from the container at `path`.
/// - xmlParse: An XML parsing error occurred.
/// - missingElement: An XML element is missing.
public enum EPUBParserError: Error {
    /// The mimetype of the EPUB is not valid.
    case wrongMimeType
    case missingFile(path: String)
    case xmlParse(underlyingError: Error)
    /// Missing rootfile in `container.xml`.
    case missingRootfile
}

extension EPUBParser: Loggable {}

/// An EPUB container parser that extracts the information from the relevant
/// files and builds a `Publication` instance out of it.
public final class EPUBParser: PublicationParser {
    private let reflowablePositionsStrategy: EPUBPositionsService.ReflowableStrategy

    /// - Parameter reflowablePositionsStrategy: Strategy used to calculate the number of positions in a reflowable resource.
    public init(reflowablePositionsStrategy: EPUBPositionsService.ReflowableStrategy = .recommended) {
        self.reflowablePositionsStrategy = reflowablePositionsStrategy
    }

    public func parse(
        asset: Asset,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard
            asset.format.conformsTo(.epub),
            case let .container(asset) = asset
        else {
            return .failure(.formatNotSupported)
        }

        do {
            let container = asset.container

            // `Encryption` indexed by HREF.
            let encryptions = await (try? EPUBEncryptionParser(container: container))?.parseEncryptions() ?? [:]

            let manifest = try await EPUBManifestParser(
                container: asset.container,
                encryptions: encryptions
            ).parseManifest()

            let deobfuscator = EPUBDeobfuscator(publicationId: manifest.metadata.identifier ?? "", encryptions: encryptions)

            return .success(Publication.Builder(
                manifest: manifest,
                container: container.map { url, resource in
                    deobfuscator.deobfuscate(resource: resource, at: url)
                },
                servicesBuilder: .init(
                    content: DefaultContentService.makeFactory(
                        resourceContentIteratorFactories: [
                            HTMLResourceContentIterator.Factory(),
                        ]
                    ),
                    positions: EPUBPositionsService.makeFactory(reflowableStrategy: reflowablePositionsStrategy),
                    search: StringSearchService.makeFactory()
                )
            ))
        } catch {
            return .failure(.reading(.decoding(error)))
        }
    }
}
