//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation

/// Shared model for a Readium Publication.
public class Publication: Loggable {
    private var manifest: Manifest
    private let fetcher: Fetcher
    private let services: [PublicationService]

    public var context: [String] { manifest.context }
    public var metadata: Metadata { manifest.metadata }
    public var links: [Link] { manifest.links }
    /// Identifies a list of resources in reading order for the publication.
    public var readingOrder: [Link] { manifest.readingOrder }
    /// Identifies resources that are necessary for rendering the publication.
    public var resources: [Link] { manifest.resources }
    /// Identifies the collection that contains a table of contents.
    public var tableOfContents: [Link] { manifest.tableOfContents }
    public var subcollections: [String: [PublicationCollection]] { manifest.subcollections }

    public var userProperties = UserProperties()

    // The status of User Settings properties (enabled or disabled).
    public var userSettingsUIPreset: [ReadiumCSSName: Bool]? {
        didSet { userSettingsUIPresetUpdated?(userSettingsUIPreset) }
    }

    /// Called when the User Settings changed.
    public var userSettingsUIPresetUpdated: (([ReadiumCSSName: Bool]?) -> Void)?

    public init(
        manifest: Manifest,
        fetcher: Fetcher = EmptyFetcher(),
        servicesBuilder: PublicationServicesBuilder = .init()
    ) {
        let weakPublication = Weak<Publication>()

        var manifest = manifest
        let services = servicesBuilder.build(
            context: PublicationServiceContext(
                publication: weakPublication,
                manifest: manifest,
                fetcher: fetcher
            )
        )
        manifest.links.append(contentsOf: services.flatMap(\.links))

        self.manifest = manifest
        self.fetcher = fetcher
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
    public var baseURL: HTTPURL? {
        links.first(withRel: .`self`)
            .takeIf { !$0.templated }
            .flatMap { HTTPURL(string: $0.href) }
    }

    /// Finds the first Link having the given `href` in the publication's links.
    public func link(withHREF href: String) -> Link? {
        manifest.link(withHREF: href)
    }

    /// Finds the first link with the given relation in the publication's links.
    public func link(withRel rel: LinkRelation) -> Link? {
        manifest.link(withRel: rel)
    }

    /// Finds all the links with the given relation in the publication's links.
    public func links(withRel rel: LinkRelation) -> [Link] {
        manifest.links(withRel: rel)
    }

    /// Returns the resource targeted by the given `link`.
    public func get(_ link: Link) -> Resource {
        assert(!link.templated, "You must expand templated links before calling `Publication.get`")

        return services.first { $0.get(link: link) }
            ?? fetcher.get(link)
    }

    /// Returns the resource targeted by the given `href`.
    public func get(_ href: String) -> Resource {
        var link = link(withHREF: href) ?? Link(href: href)
        // Uses the original href to keep the query parameters
        link.href = href
        link.templated = false
        return get(link)
    }

    /// Closes any opened resource associated with the `Publication`, including `services`.
    public func close() {
        fetcher.close()
        services.forEach { $0.close() }
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

    /// Sets the URL where this `Publication`'s RWPM manifest is served.
    @available(*, unavailable, message: "Not used anymore")
    public func setSelfLink(href: String?) { fatalError() }

    /// Represents a Readium Web Publication Profile a `Publication` can conform to.
    ///
    /// For a list of supported profiles, see the registry:
    /// https://readium.org/webpub-manifest/profiles/
    public struct Profile: Hashable {
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

    /// Errors occurring while opening a Publication.
    public enum OpeningError: LocalizedError {
        /// The file format could not be recognized by any parser.
        case unsupportedFormat
        /// The publication file was not found on the file system.
        case notFound
        /// The publication parser failed with the given underlying error.
        case parsingFailed(Error)
        /// We're not allowed to open the publication at all, for example because it expired.
        case forbidden(Error?)
        /// The publication can't be opened at the moment, for example because of a networking error.
        /// This error is generally temporary, so the operation may be retried or postponed.
        case unavailable(Error?)
        /// The provided credentials are incorrect and we can't open the publication in a
        /// `restricted` state (e.g. for a password-protected ZIP).
        case incorrectCredentials

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return ReadiumSharedLocalizedString("Publication.OpeningError.unsupportedFormat")
            case .notFound:
                return ReadiumSharedLocalizedString("Publication.OpeningError.notFound")
            case .parsingFailed:
                return ReadiumSharedLocalizedString("Publication.OpeningError.parsingFailed")
            case .forbidden:
                return ReadiumSharedLocalizedString("Publication.OpeningError.forbidden")
            case .unavailable:
                return ReadiumSharedLocalizedString("Publication.OpeningError.unavailable")
            case .incorrectCredentials:
                return ReadiumSharedLocalizedString("Publication.OpeningError.incorrectCredentials")
            }
        }
    }

    /// Holds the components of a `Publication` to build it.
    ///
    /// A `Publication`'s construction is distributed over the Streamer and its parsers, and since
    /// `Publication` is immutable, it's useful to pass the parts around before actually building
    /// it.
    public struct Builder {
        /// Transform which can be used to modify a `Publication`'s components before building it.
        /// For example, to add Publication Services or wrap the root Fetcher.
        public typealias Transform = (_ mediaType: MediaType, _ manifest: inout Manifest, _ fetcher: inout Fetcher, _ services: inout PublicationServicesBuilder) -> Void

        private let mediaType: MediaType
        private var manifest: Manifest
        private var fetcher: Fetcher
        private var servicesBuilder: PublicationServicesBuilder

        /// Closure which will be called once the `Publication` is built.
        /// This is used for backwrad compatibility, until `Publication` is purely immutable.
        private let setupPublication: ((Publication) -> Void)?

        public init(
            mediaType: MediaType,
            manifest: Manifest,
            fetcher: Fetcher,
            servicesBuilder: PublicationServicesBuilder = .init(),
            setupPublication: ((Publication) -> Void)? = nil
        ) {
            self.mediaType = mediaType
            self.manifest = manifest
            self.fetcher = fetcher
            self.servicesBuilder = servicesBuilder
            self.setupPublication = setupPublication
        }

        public mutating func apply(_ transform: Transform?) {
            guard let transform = transform else {
                return
            }

            transform(mediaType, &manifest, &fetcher, &servicesBuilder)
        }

        /// Builds the `Publication` from its parts.
        public func build() -> Publication {
            let publication = Publication(
                manifest: manifest,
                fetcher: fetcher,
                servicesBuilder: servicesBuilder
            )
            setupPublication?(publication)
            return publication
        }
    }

    /// Format of the publication, if specified.
    @available(*, unavailable, message: "Use publication.conforms(to:) to check the profile of a Publication")
    public var format: Format { fatalError() }
    /// Version of the publication's format, eg. 3 for EPUB 3
    @available(*, unavailable, message: "This API will be removed in a future version. If you still need it, please explain your use case at https://github.com/readium/swift-toolkit/issues/new")
    public var formatVersion: String? { fatalError() }

    @available(*, unavailable, message: "Use publication.conforms(to:) to check the profile of a Publication")
    public enum Format: Equatable, Hashable {
        /// Formats natively supported by Readium.
        case cbz, epub, pdf, webpub
        /// Default value when the format is not specified.
        case unknown
    }
}
