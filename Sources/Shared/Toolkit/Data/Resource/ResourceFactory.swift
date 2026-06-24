//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A factory to create ``Resource`` instances from absolute URLs.
public protocol ResourceFactory: Sendable {
    /// Creates a ``Resource`` to access the content at `url`.
    func make(url: AbsoluteURL) async -> Result<Resource, ResourceMakeError>
}

public enum ResourceMakeError: Error, Sendable {
    /// URL scheme not supported by the ``ResourceFactory``.
    case schemeNotSupported(URLScheme)
}

/// Default implementation of ``ResourceFactory`` supporting file and http
/// schemes.
public final class DefaultResourceFactory: ResourceFactory {
    private let factory: CompositeResourceFactory

    /// - Parameters:
    ///   - httpClient: HTTP client used to support HTTP schemes.
    ///   - additionalFactories: Additional ``ResourceFactory`` to support more
    ///     schemes.
    public init(
        httpClient: HTTPClient,
        additionalFactories: [ResourceFactory] = []
    ) {
        factory = CompositeResourceFactory(additionalFactories + [
            FileResourceFactory(),
            HTTPResourceFactory(client: httpClient),
        ])
    }

    public func make(url: any AbsoluteURL) async -> Result<any Resource, ResourceMakeError> {
        await factory.make(url: url)
    }
}

/// A composite ``ResourceFactory`` which tries several factories until it
/// finds one which supports the URL scheme.
public final class CompositeResourceFactory: ResourceFactory {
    private let factories: [ResourceFactory]

    public init(_ factories: [ResourceFactory]) {
        self.factories = factories
    }

    public func make(url: any AbsoluteURL) async -> Result<any Resource, ResourceMakeError> {
        for factory in factories {
            switch await factory.make(url: url) {
            case let .success(resource):
                return .success(resource)
            case let .failure(error):
                switch error {
                case .schemeNotSupported:
                    continue
                }
            }
        }
        return .failure(.schemeNotSupported(url.scheme))
    }
}
