//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A factory to create ``Resource`` instances from absolute URLs.
public protocol ResourceFactory {
    /// Creates a ``Resource`` to access the content at `url`.
    func make(url: AbsoluteURL) async throws(ResourceMakeError) -> Resource
}

public enum ResourceMakeError: Error, Sendable {
    /// URL scheme not supported by the ``ResourceFactory``.
    case schemeNotSupported(URLScheme)
}

/// Default implementation of ``ResourceFactory`` supporting file and http
/// schemes.
public final class DefaultResourceFactory: CompositeResourceFactory {
    /// - Parameters:
    ///   - httpClient: HTTP client used to support HTTP schemes.
    ///   - additionalFactories: Additional ``ResourceFactory`` to support more
    ///     schemes.
    public init(
        httpClient: HTTPClient,
        additionalFactories: [ResourceFactory] = []
    ) {
        super.init(additionalFactories + [
            FileResourceFactory(),
            HTTPResourceFactory(client: httpClient),
        ])
    }
}

/// A composite ``ResourceFactory`` which tries several factories until it
/// finds one which supports the URL scheme.
public class CompositeResourceFactory: ResourceFactory {
    private let factories: [ResourceFactory]

    public init(_ factories: [ResourceFactory]) {
        self.factories = factories
    }

    public func make(url: any AbsoluteURL) async throws(ResourceMakeError) -> any Resource {
        for factory in factories {
            do {
                return try await factory.make(url: url)
            } catch {
                switch error {
                case .schemeNotSupported:
                    continue
                }
            }
        }
        throw .schemeNotSupported(url.scheme)
    }
}
