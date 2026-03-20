//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Error while trying to retrieve an asset from a ``Resource`` or a
/// ``Container``.
public enum AssetRetrieveError: Error, Sendable {
    /// The format of the resource is not recognized.
    case formatNotSupported

    /// An error occurred when trying to read the asset.
    case reading(ReadError)
}

/// Error while trying to retrieve an asset from an URL.
public enum AssetRetrieveURLError: Error, Sendable {
    /// The scheme (e.g. http, file, content) for the requested URL is not
    /// supported.
    case schemeNotSupported(URLScheme)

    /// The format of the resource at the requested URL is not recognized.
    case formatNotSupported

    /// An error occurred when trying to read the asset.
    case reading(ReadError)
}

/// Retrieves an ``Asset`` instance that provides read-only access to the
/// resource(s) of an asset stored at a given ``AbsoluteURL`` and its
/// ``Format``.
public final class AssetRetriever {
    private let formatSniffer: FormatSniffer
    private let resourceFactory: ResourceFactory
    private let archiveOpener: ArchiveOpener

    /// Creates an ``AssetRetriever`` with the default components.
    public convenience init(
        httpClient: HTTPClient
    ) {
        self.init(
            formatSniffer: DefaultFormatSniffer(),
            resourceFactory: DefaultResourceFactory(httpClient: httpClient),
            archiveOpener: DefaultArchiveOpener()
        )
    }

    /// Creates an ``AssetRetriever`` using the given custom components.
    public init(
        formatSniffer: FormatSniffer,
        resourceFactory: ResourceFactory,
        archiveOpener: ArchiveOpener
    ) {
        self.formatSniffer = formatSniffer
        self.resourceFactory = resourceFactory
        self.archiveOpener = archiveOpener
    }

    /// Sniffs the format of the content available at `url`.
    public func sniffFormat(of url: AbsoluteURL, hints: FormatHints = FormatHints()) async throws(AssetRetrieveURLError) -> Format {
        try await retrieve(url: url, hints: hints).format
    }

    /// Sniffs the format of a `Resource`.
    public func sniffFormat(of resource: Resource, hints: FormatHints = FormatHints()) async throws(AssetRetrieveError) -> Format {
        try await retrieve(resource: resource, hints: hints).format
    }

    /// Sniffs the format of a `Container`.
    public func sniffFormat(of container: Container, hints: FormatHints = FormatHints()) async throws(AssetRetrieveError) -> Format {
        try await retrieve(container: container, hints: hints).format
    }

    /// Retrieves an asset from a URL and a known format.
    public func retrieve(url: AbsoluteURL, format: Format) async throws(AssetRetrieveURLError) -> Asset {
        let resource = try await openResource(at: url)
        let container: ContainerAsset?
        do {
            container = try await tryOpenArchive(with: resource, format: format)
        } catch {
            throw .reading(error)
        }
        if let container = container {
            return .container(container)
        } else {
            return .resource(ResourceAsset(resource: resource, format: format))
        }
    }

    /// Retrieves an asset from a URL and a known media type.
    public func retrieve(url: AbsoluteURL, mediaType: MediaType) async throws(AssetRetrieveURLError) -> Asset {
        try await retrieve(url: url, hints: FormatHints(mediaType: mediaType))
    }

    /// Retrieves an asset from a URL of unknown format.
    public func retrieve(url: AbsoluteURL, hints: FormatHints = FormatHints()) async throws(AssetRetrieveURLError) -> Asset {
        let resource = try await openResource(at: url)
        do {
            return try await retrieve(resource: resource, hints: hints)
        } catch {
            throw AssetRetrieveURLError(error)
        }
    }

    /// Retrieves an asset from an already opened resource.
    public func retrieve(resource: Resource, hints: FormatHints = FormatHints()) async throws(AssetRetrieveError) -> Asset {
        let filledHints: FormatHints
        do {
            filledHints = try await resource.fill(hints: hints)
        } catch {
            throw .reading(error)
        }
        return try await refine(
            format: formatSniffer.sniffHints(filledHints) ?? .null,
            of: .resource(ResourceAsset(resource: resource, format: .null))
        )
    }

    /// Retrieves an asset from an already opened container.
    public func retrieve(container: Container, hints: FormatHints = FormatHints()) async throws(AssetRetrieveError) -> Asset {
        try await refine(
            format: formatSniffer.sniffHints(hints) ?? .null,
            of: .container(ContainerAsset(container: container, format: .null))
        )
    }

    private func openResource(at url: AbsoluteURL) async throws(AssetRetrieveURLError) -> Resource {
        do {
            return try await resourceFactory.make(url: url)
        } catch {
            switch error {
            case let .schemeNotSupported(scheme):
                throw .schemeNotSupported(scheme)
            }
        }
    }

    /// Will sniff `asset` to refine the given `format`.
    ///
    /// For example, if `format` is `zip`, it might be refined in `zip, epub`
    private func refine(
        format: Format,
        of asset: Asset
    ) async throws(AssetRetrieveError) -> Asset {
        let refinedFormat: Format?
        do {
            refinedFormat = try await formatSniffer.sniffAsset(asset: asset, refining: format)
        } catch {
            throw .reading(error)
        }
        if let refinedFormat = refinedFormat, refinedFormat.refines(format) {
            return try await refine(format: refinedFormat, of: asset)
        }

        if case let .resource(asset) = asset {
            let containerAsset: ContainerAsset?
            do {
                containerAsset = try await tryOpenArchive(with: asset.resource, format: format)
            } catch {
                throw .reading(error)
            }
            if let containerAsset = containerAsset {
                return try await refine(format: format, of: .container(containerAsset))
            }
        }

        guard format.hasSpecification else {
            throw .formatNotSupported
        }

        var asset = asset
        asset.format = format
        return asset
    }

    private func tryOpenArchive(with resource: Resource, format: Format) async throws(ReadError) -> ContainerAsset? {
        do {
            return try await archiveOpener.open(resource: resource, format: format)
        } catch {
            switch error {
            case .formatNotSupported:
                return nil
            case let .reading(error):
                throw error
            }
        }
    }
}

private extension AssetRetrieveURLError {
    init(_ error: AssetRetrieveError) {
        switch error {
        case .formatNotSupported:
            self = .formatNotSupported
        case let .reading(error):
            self = .reading(error)
        }
    }
}

private extension Resource {
    /// Fills in the given `hints` with additional metadata extracted from the
    /// resource properties.
    func fill(hints: FormatHints) async throws(ReadError) -> FormatHints {
        let properties = try await properties()
        var hints = hints

        if let mediaType = properties.mediaType {
            hints.mediaTypes.append(mediaType)
        }

        if let fileExtension = properties.filename
            .map({ URL(fileURLWithPath: $0).pathExtension })
            .takeIf({ !$0.isEmpty })
            .map({ FileExtension(rawValue: $0) })
        {
            hints.fileExtensions.append(fileExtension)
        }

        return hints
    }
}

private extension FormatSniffer {
    func sniffAsset(asset: Asset, refining format: Format) async throws(ReadError) -> Format? {
        switch asset {
        case let .resource(asset):
            return try await sniffBlob(FormatSnifferBlob(source: asset.resource), refining: format)
        case let .container(asset):
            return try await sniffContainer(asset.container, refining: format)
        }
    }
}
