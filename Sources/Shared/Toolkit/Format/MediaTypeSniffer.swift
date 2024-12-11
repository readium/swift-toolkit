//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation
import ReadiumFuzi

public extension MediaType {
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    typealias Sniffer = (_ context: Any) -> MediaType?

    @available(*, unavailable, renamed: "MediaType.init(_:)", message: "Create the MediaType directly with MediaType(type)")
    static func of(mediaType: String?) -> MediaType? {
        fatalError()
    }

    /// resolves a media type from a single file extension and media type hint, without checking the
    /// actual content.
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    static func of(mediaType: String? = nil, fileExtension: String? = nil, sniffers: [Sniffer] = []) -> MediaType? {
        fatalError()
    }

    /// Resolves a media type from file extension and media type hints, without checking the actual
    /// content.
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    static func of(mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer] = []) -> MediaType? {
        fatalError()
    }

    /// Resolves a media type from a local file path.
    /// **Warning**: This API should never be called from the UI thread.
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    static func of(_ file: FileURL, mediaType: String? = nil, fileExtension: String? = nil, sniffers: [Sniffer] = []) -> MediaType? {
        fatalError()
    }

    /// Resolves a media type from a local file path.
    /// **Warning**: This API should never be called from the UI thread.
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    static func of(_ file: FileURL, mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer] = []) -> MediaType? {
        fatalError()
    }

    /// Resolves a media type from bytes, e.g. from an HTTP response.
    /// **Warning**: This API should never be called from the UI thread.
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    static func of(_ data: @escaping () -> Data, mediaType: String? = nil, fileExtension: String? = nil, sniffers: [Sniffer] = []) -> MediaType? {
        fatalError()
    }

    /// Resolves a media type from bytes, e.g. from an HTTP response.
    /// **Warning**: This API should never be called from the UI thread.
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    static func of(_ data: @escaping () -> Data, mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer] = []) -> MediaType? {
        fatalError()
    }

    /// Resolves a media type from a sniffer context.
    ///
    /// Sniffing a media type is done in two rounds, because we want to give an opportunity to all
    /// sniffers to return a `MediaType` quickly before inspecting the content itself:
    /// * *Light Sniffing* checks only the provided file extension or media type hints.
    /// * *Heavy Sniffing* reads the bytes to perform more advanced sniffing.
    @available(*, unavailable, message: "Use an `AssetRetriever` to sniff a `Format` instead")
    private static func of(content: Any, mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer]) -> MediaType? {
        fatalError()
    }
}

public extension URLResponse {
    /// Sniffs the media type for this `URLResponse`, using the default media type sniffers.
    @available(*, unavailable, message: "Use an AssetRetriever to retrieve the media type of an HTTP resource")
    var mediaType: MediaType? { fatalError() }

    /// Resolves the media type for this `URLResponse`, with optional extra file extension and media
    /// type hints.
    @available(*, unavailable, message: "Use an AssetRetriever to retrieve the media type of an HTTP resource")
    func sniffMediaType(data: (() -> Data)? = nil, mediaTypes: [String] = [], fileExtensions: [String] = []) -> MediaType? {
        fatalError()
    }
}
