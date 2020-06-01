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
    
    private var manifest: PublicationManifest
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
    public var otherCollections: [PublicationCollection] { manifest.otherCollections }

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
        manifest: PublicationManifest,
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
    public convenience init(json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        self.init(manifest: try PublicationManifest(json: json, normalizeHref: normalizeHref))
    }
    
    /// Returns the Readium Web Publication Manifest as JSON.
    public var jsonManifest: Data? {
        serializeJSONData(manifest.json)
    }
    
    public func findService<T>(_ serviceType: T.Type) -> T? {
        return services.first { $0 is T } as? T
    }
    
    /// Returns the resource targeted by the given `link`.
    ///
    /// The `link.href` property is searched for in the `links`, `readingOrder` and `resources` properties
    /// to find the matching manifest Link. This is to make sure that
    /// the Link given to the Fetcher contains all properties declared in the manifest.
    ///
    /// The properties are searched recursively following `Link.alternate`, then `Link.children`.
    /// But only after comparing all the links at the current level.
    public func get(_ link: Link) -> Resource {
        let link = self.link(withHref: link.href) ?? link
        for service in services {
            if let response = service.get(link: link) {
                return response
            }
        }
        return fetcher.get(link)
    }
    
    /// Returns the resource targeted by the given `href`.
    public func get(_ href: String) -> Resource {
        return get(Link(href: href))
    }

    /// Sets the URL where this `Publication`'s RWPM manifest is served.
    public func setSelfLink(href: String?) {
        manifest.links.removeAll { $0.rels.contains("self") }
        if let href = href {
            manifest.links.insert(Link(
                href: href,
                type: MediaType.webpubManifest.string,
                rel: "self"
            ), at: 0)
        }
    }

    /// Finds the first `Link` having the given `rel` in the publication's links.
    public func link(withRel rel: String) -> Link? {
        return link { $0.rels.contains(rel) }
    }

    /// Finds the first `Link` having the given `rel` matching the given `predicate`, in the
    /// publications' links.
    internal func link(withRelMatching predicate: (String) -> Bool) -> Link? {
        for link in links {
            for rel in link.rels {
                if predicate(rel) {
                    return link
                }
            }
        }
        return nil
    }
    
    /// Finds the first Link having the given `href` in the publication's links.
    public func link(withHref href: String) -> Link? {
        return link { $0.href == href }
    }
    
    /// Finds the first Link matching the given predicate in the publication's `Link` properties: `resources`, `readingOrder` and `links`.
    public func link(where predicate: (Link) -> Bool) -> Link? {
        return resources.first(where: predicate)
            ?? readingOrder.first(where: predicate)
            ?? links.first(where: predicate)
    }
    
    /// Finds a resource `Link` (asset or readingOrder item) at the given relative path.
    ///
    /// - Parameter href: The relative path to the resource
    public func resource(withHref href: String) -> Link? {
        return readingOrder.first(withHref: href)
            ?? resources.first(withHref: href)
    }
    
    /// Finds the first link to the publication's cover.
    /// The link must have a `cover` rel.
    public var coverLink: Link? {
        return link(withRel: "cover")
    }

    /// Return the publication base URL based on the selfLink.
    /// e.g.: "http://localhost:8000/publicationName/".
    public var baseURL: URL? {
        guard let link = links.first(withRel: "self"),
            let url = URL(string: link.href)?.deletingLastPathComponent() else
        {
            log(.warning, "No or invalid `self` link found in publication")
            return nil
        }
        return url
    }
    
    /// Generates an URL to a publication's `Link`.
    public func url(to link: Link?) -> URL? {
        return url(to: link?.href)
    }
    
    /// Generates an URL to a publication's `href`.
    public func url(to href: String?) -> URL? {
        guard let href = href else {
            return nil
        }
        
        if let url = URL(string: href), url.scheme != nil {
            return url
        } else if let baseURL = baseURL {
            return baseURL.appendingPathComponent(href.removingPrefix("/"))
        }
        
        return nil
    }
    
    /// Returns whether all the `Link` in the reading order match the given `predicate`.
    internal func allReadingOrder(_ predicate: (Link) -> Bool) -> Bool {
        return readingOrder.allSatisfy(predicate)
    }
    
    /// Returns whether all the resources in the reading order are bitmaps.
    internal var allReadingOrderIsBitmap: Bool {
        allReadingOrder { link in
            link.mediaType?.isBitmap ?? false
        }
    }
    
    /// Returns whether all the resources in the reading order are audio clips.
    internal var allReadingOrderIsAudio: Bool {
        allReadingOrder { link in
            link.mediaType?.isAudio ?? false
        }
    }
    
    /// Returns whether all the resources in the reading order are contained in any of the given media types.
    internal func allReadingOrderMatches(mediaType: MediaType...) -> Bool {
        allReadingOrder { link in
            mediaType.first { link.mediaType?.matches($0) ?? false } != nil
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
            case .webpubManifest, .audiobookManifest:
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
    
}
