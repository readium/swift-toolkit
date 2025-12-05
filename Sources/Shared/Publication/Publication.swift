//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation
import ReadiumInternal

/// Shared model for a Readium Publication.
public class Publication: Closeable, Loggable {
    public var manifest: Manifest
    private let container: Container
    private let services: [PublicationService]

    public var context: [String] { manifest.context }
    public var metadata: Metadata { manifest.metadata }
    public var links: [Link] { manifest.links }
    /// Identifies a list of resources in reading order for the publication.
    public var readingOrder: [Link] { manifest.readingOrder }
    /// Identifies resources that are necessary for rendering the publication.
    public var resources: [Link] { manifest.resources }
    public var subcollections: [String: [PublicationCollection]] { manifest.subcollections }

    public init(
        manifest: Manifest,
        container: Container = EmptyContainer(),
        servicesBuilder: PublicationServicesBuilder = .init()
    ) {
        let weakPublication = Weak<Publication>()

        var manifest = manifest
        let services = servicesBuilder.build(
            context: PublicationServiceContext(
                publication: weakPublication,
                manifest: manifest,
                container: container
            )
        )
        manifest.links.append(contentsOf: services.flatMap(\.links))

        self.manifest = manifest
        self.container = container
        self.services = services

        weakPublication.ref = self
    }

    /// Parses a Readium Web Publication Manifest.
    /// https://readium.org/webpub-manifest/schema/publication.schema.json
    public convenience init(json: Any, warnings: WarningLogger? = nil) throws {
        try self.init(manifest: Manifest(json: json, warnings: warnings))
    }

    /// Returns the Readium Web Publication Manifest as JSON.
    public var jsonManifest: String? {
        serializeJSONString(manifest.json)
    }

    /// Returns whether this publication conforms to the given Readium Web Publication Profile.
    public func conforms(to profile: Profile) -> Bool {
        manifest.conforms(to: profile)
    }

    /// The URL where this publication is served, computed from the `Link` with `self` relation.
    ///
    /// e.g. https://provider.com/pub1293/manifest.json gives https://provider.com/pub1293/
    public var baseURL: HTTPURL? { manifest.baseURL }

    /// Finds the first Link having the given `href` in the publication's links.
    public func linkWithHREF<T: URLConvertible>(_ href: T) -> Link? {
        manifest.linkWithHREF(href)
    }

    /// Finds the first link with the given relation in the publication's links.
    public func linkWithRel(_ rel: LinkRelation) -> Link? {
        manifest.linkWithRel(rel)
    }

    /// Finds all the links with the given relation in the publication's links.
    public func linksWithRel(_ rel: LinkRelation) -> [Link] {
        manifest.linksWithRel(rel)
    }

    /// Returns the resource targeted by the given `link`.
    public func get(_ link: Link) -> Resource? {
        assert(!link.templated, "You must expand templated links before calling `Publication.get`")
        return get(link.url())
    }

    /// Returns the resource targeted by the given `href`.
    public func get<T: URLConvertible>(_ href: T) -> Resource? {
        services.first { $0.get(href) }
            // Try first the original href and falls back to href without query and fragment.
            ?? container[href]
            ?? container[href.anyURL.removingQuery().removingFragment()]
    }

    /// Finds the first `Publication.Service` implementing the given service type.
    ///
    /// e.g. `findService(PositionsService.self)`
    public func findService<T>(_ serviceType: T.Type) -> T? {
        services.first { $0 is T } as? T
    }

    /// Finds all the services implementing the given service type.
    public func findServices<T>(_ serviceType: T.Type) -> [T] {
        services.filter { $0 is T } as! [T]
    }

    /// Historically, we used to have "absolute" HREFs in the manifest:
    ///  - starting with a `/` for packaged publications.
    ///  - resolved to the `self` link for remote publications.
    ///
    /// We removed the normalization and now use relative HREFs everywhere, but
    /// we still need to support the locators created with the old absolute
    /// HREFs.
    public func normalizeLocator(_ locator: Locator) -> Locator {
        var locator = locator

        if let baseURL = baseURL { // Remote publication
            // Check that the locator HREF relative to `baseURL` exists in the manifest.
            if let relativeHREF = baseURL.relativize(locator.href) {
                locator.href = linkWithHREF(relativeHREF)?.url()
                    ?? relativeHREF.anyURL
            }

        } else { // Packaged publication
            if let href = AnyURL(string: locator.href.string.removingPrefix("/")) {
                locator.href = href
            }
        }

        return locator
    }

    /// Represents a Readium Web Publication Profile a `Publication` can conform to.
    ///
    /// For a list of supported profiles, see the registry:
    /// https://readium.org/webpub-manifest/profiles/
    public struct Profile: Hashable, Sendable {
        public let uri: String

        public init(_ uri: String) {
            self.uri = uri
        }

        /// Profile for EPUB publications.
        public static let epub = Profile("https://readium.org/webpub-manifest/profiles/epub")
        /// Profile for audiobooks.
        public static let audiobook = Profile("https://readium.org/webpub-manifest/profiles/audiobook")
        /// Profile for visual narratives (comics, manga and bandes dessinées).
        public static let divina = Profile("https://readium.org/webpub-manifest/profiles/divina")
        /// Profile for PDF documents.
        public static let pdf = Profile("https://readium.org/webpub-manifest/profiles/pdf")
    }

    /// Holds the components of a `Publication` to build it.
    ///
    /// A `Publication`'s construction is distributed over the Streamer and its
    /// parsers, and since `Publication` is immutable, it's useful to pass the
    /// parts around before actually building it.
    public struct Builder {
        /// Transform which can be used to modify a `Publication`'s components
        /// before building it. For example, to add Publication Services or
        /// wrap the root Container.
        public typealias Transform = (
            _ manifest: inout Manifest,
            _ container: inout Container,
            _ services: inout PublicationServicesBuilder
        ) -> Void

        private var manifest: Manifest
        private var container: Container
        private var servicesBuilder: PublicationServicesBuilder

        public init(
            manifest: Manifest,
            container: Container,
            servicesBuilder: PublicationServicesBuilder = .init()
        ) {
            self.manifest = manifest
            self.container = container
            self.servicesBuilder = servicesBuilder
        }

        public mutating func apply(_ transform: Transform?) {
            guard let transform = transform else {
                return
            }

            transform(&manifest, &container, &servicesBuilder)
        }

        /// Builds the `Publication` from its parts.
        public func build() -> Publication {
            Publication(
                manifest: manifest,
                container: container,
                servicesBuilder: servicesBuilder
            )
        }
    }
}
