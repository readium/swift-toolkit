//
//  Publication.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Olivier Körner on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import CoreServices
import Foundation

/// Shared model for a Readium Publication.
public class Publication: Loggable {

    /// Format of the publication, if specified.
    public var format: Format = .unknown
    /// Version of the publication's format, eg. 3 for EPUB 3
    public var formatVersion: String?
    
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
    
    /// Returns the content layout style for the default publication language.
    public var contentLayout: ContentLayout {
        metadata.contentLayout
    }
    
    /// Returns the content layout style for the given language code.
    public func contentLayout(forLanguage language: String?) -> ContentLayout {
        return metadata.contentLayout(forLanguage: language)
    }
    
    public init(
        manifest: Manifest,
        fetcher: Fetcher = EmptyFetcher(),
        servicesBuilder: PublicationServicesBuilder = .init(),
        format: Format = .unknown,
        formatVersion: String? = nil
    ) {
        var manifest = manifest
        let services = servicesBuilder.build(context: .init(manifest: manifest, fetcher: fetcher))
        manifest.links.append(contentsOf: services.flatMap { $0.links })
        
        self.manifest = manifest
        self.fetcher = fetcher
        self.services = services
        self.format = format
        self.formatVersion = formatVersion
    }
    
    /// Parses a Readium Web Publication Manifest.
    /// https://readium.org/webpub-manifest/schema/publication.schema.json
    public convenience init(json: Any, warnings: WarningLogger? = nil) throws {
        self.init(manifest: try Manifest(json: json, warnings: warnings))
    }
    
    /// Returns the Readium Web Publication Manifest as JSON.
    public var jsonManifest: String? {
        serializeJSONString(manifest.json)
    }
    
    /// The URL where this publication is served, computed from the `Link` with `self` relation.
    ///
    /// e.g. https://provider.com/pub1293/manifest.json gives https://provider.com/pub1293/
    public var baseURL: URL? {
        links.first(withRel: .self)
            .flatMap { URL(string: $0.href)?.deletingLastPathComponent() }
    }
    
    /// Finds the first Link having the given `href` in the publication's links.
    public func link(withHREF href: String) -> Link? {
        func deepFind(in linkLists: [Link]...) -> Link? {
            for links in linkLists {
                for link in links {
                    if link.href == href {
                        return link
                    } else if let child = deepFind(in: link.alternates, link.children) {
                        return child
                    }
                }
            }
            
            return nil
        }
        
        var link = deepFind(in: readingOrder, resources, links)
        if
            link == nil,
            let shortHREF = href.components(separatedBy: .init(charactersIn: "#?")).first,
            shortHREF != href
        {
            // Tries again, but without the anchor and query parameters.
            link = self.link(withHREF: shortHREF)
        }
        
        return link
    }
    
    /// Finds the first link with the given relation in the publication's links.
    public func link(withRel rel: LinkRelation) -> Link? {
        return manifest.link(withRel: rel)
    }
    
    /// Finds all the links with the given relation in the publication's links.
    public func links(withRel rel: LinkRelation) -> [Link] {
        return manifest.links(withRel: rel)
    }

    /// Returns the resource targeted by the given `link`.
    public func get(_ link: Link) -> Resource {
        assert(!link.templated, "You must expand templated links before calling `Publication.get`")

        return services.first { $0.get(link: link) }
            ?? fetcher.get(link)
    }
    
    /// Returns the resource targeted by the given `href`.
    public func get(_ href: String) -> Resource {
        let link = self.link(withHREF: href)?
            // Uses the original href to keep the query parameters
            .copy(href: href, templated: false)
        
        return get(link ?? Link(href: href))
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
        return services.first { $0 is T } as? T
    }
    
    /// Finds all the services implementing the given service type.
    public func findServices<T>(_ serviceType: T.Type) -> [T] {
        return services.filter { $0 is T } as! [T]
    }

    /// Sets the URL where this `Publication`'s RWPM manifest is served.
    public func setSelfLink(href: String?) {
        manifest.links.removeAll { $0.rels.contains(.self) }
        if let href = href {
            manifest.links.insert(Link(
                href: href,
                type: MediaType.readiumWebPubManifest.string,
                rel: .self
            ), at: 0)
        }
    }

    public enum Format: Equatable, Hashable {
        /// Formats natively supported by Readium.
        case cbz, epub, pdf, webpub
        /// Default value when the format is not specified.
        case unknown

        /// Finds the format for the given mimetype.
        public init(mimetype: String?) {
            guard let mimetype = mimetype else {
                self = .unknown
                return
            }
            self.init(mimetypes: [mimetype])
        }

        /// Finds the format from a list of possible mimetypes or fallback on a file extension.
        public init(mimetypes: [String] = [], fileExtension: String? = nil) {
            self.init(format: .of(mediaTypes: mimetypes, fileExtensions: Array(ofNotNil: fileExtension)))
        }
        
        /// Finds the format of the publication at the given url.
        /// Uses the format declared as exported UTIs in the app's Info.plist, or fallbacks on the file extension.
        ///
        /// - Parameter mimetype: Fallback mimetype if the UTI can't be determined.
        public init(file: URL, mimetype: String) {
            self.init(file: file, mimetypes: [mimetype])
        }

        /// Finds the format of the publication at the given url.
        /// Uses the format declared as exported UTIs in the app's Info.plist, or fallbacks on the file extension.
        ///
        /// - Parameter mimetypes: Fallback mimetypes if the UTI can't be determined.
        public init(file: URL, mimetypes: [String] = []) {
            self.init(format: .of(file, mediaTypes: mimetypes, fileExtensions: []))
        }
        
        private init(format: R2Shared.Format?) {
            guard let format = format else {
                self = .unknown
                return
            }
            switch format {
            case .epub:
                self = .epub
            case .cbz:
                self = .cbz
            case .pdf, .lcpProtectedPDF:
                self = .pdf
            case .readiumWebPubManifest, .readiumAudiobookManifest:
                self = .webpub
            default:
                self = .unknown
            }
        }
        
        @available(*, unavailable, renamed: "init(file:)")
        public init(url: URL) {
            self.init(file: url)
        }

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
                return R2SharedLocalizedString("Publication.OpeningError.unsupportedFormat")
            case .notFound:
                return R2SharedLocalizedString("Publication.OpeningError.notFound")
            case .parsingFailed:
                return R2SharedLocalizedString("Publication.OpeningError.parsingFailed")
            case .forbidden:
                return R2SharedLocalizedString("Publication.OpeningError.forbidden")
            case .unavailable:
                return R2SharedLocalizedString("Publication.OpeningError.unavailable")
            case .incorrectCredentials:
                return R2SharedLocalizedString("Publication.OpeningError.incorrectCredentials")
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
        public typealias Transform = (_ format: R2Shared.Format, _ manifest: inout Manifest, _ fetcher: inout Fetcher, _ services: inout PublicationServicesBuilder) -> Void
        
        private let fileFormat: R2Shared.Format
        private let publicationFormat: Format
        private var manifest: Manifest
        private var fetcher: Fetcher
        private var servicesBuilder: PublicationServicesBuilder
        
        /// Closure which will be called once the `Publication` is built.
        /// This is used for backwrad compatibility, until `Publication` is purely immutable.
        private let setupPublication: ((Publication) -> Void)?
        
        public init(fileFormat: R2Shared.Format, publicationFormat: Format, manifest: Manifest, fetcher: Fetcher, servicesBuilder: PublicationServicesBuilder = .init(), setupPublication: ((Publication) -> Void)? = nil) {
            self.fileFormat = fileFormat
            self.publicationFormat = publicationFormat
            self.manifest = manifest
            self.fetcher = fetcher
            self.servicesBuilder = servicesBuilder
            self.setupPublication = setupPublication
        }
        
        public mutating func apply(_ transform: Transform?) {
            guard let transform = transform else {
                return
            }
            
            transform(fileFormat, &manifest, &fetcher, &servicesBuilder)
        }

        /// Builds the `Publication` from its parts.
        public func build() -> Publication {
            let publication = Publication(
                manifest: manifest,
                fetcher: fetcher,
                servicesBuilder: servicesBuilder
            )
            publication.format = publicationFormat
            setupPublication?(publication)
            return publication
        }
    }

}
