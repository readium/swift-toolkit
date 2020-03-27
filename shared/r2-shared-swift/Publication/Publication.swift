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
public class Publication: JSONEquatable, Loggable {

    /// Format of the publication, if specified.
    public var format: Format = .unknown
    /// Version of the publication's format, eg. 3 for EPUB 3
    public var formatVersion: String?
    
    /// Readium Web Publication
    /// See. https://readium.org/webpub-manifest/
    
    public var context: [String]  // @context
    public var metadata: Metadata
    public var links: [Link]
    public var readingOrder: [Link]
    public var resources: [Link]
    public var tableOfContents: [Link]
    public var otherCollections: [PublicationCollection]

    /// Factory used to build lazily the `positionList`.
    /// By default, a parser will set this to parse the `positionList` from the publication. But the host app might want to overwrite this with a custom closure to implement for example a cache mechanism.
    public var positionListFactory: (Publication) -> [Locator] = { _ in [] }
    
    /// List of all the positions in the publication.
    public lazy var positions: [Locator] = positionListFactory(self)
    
    /// List of all the positions in each resource, indexed by their `href`.
    public lazy var positionsByResource: [String: [Locator]] = positions
        .reduce([:]) { mapping, position in
            var mapping = mapping
            if mapping[position.href] == nil {
                mapping[position.href] = []
            }
            mapping[position.href]?.append(position)
            return mapping
        }

    public var userProperties = UserProperties()
    
    // The status of User Settings properties (enabled or disabled).
    public var userSettingsUIPreset: [ReadiumCSSName: Bool]? {
        didSet { userSettingsUIPresetUpdated?(userSettingsUIPreset) }
    }
    
    /// Called when the User Settings changed.
    public var userSettingsUIPresetUpdated: (([ReadiumCSSName: Bool]?) -> Void)?
    
    /// Returns the content layout style for the default publication language.
    public var contentLayout: ContentLayout {
        return contentLayout(forLanguage: nil)
    }
    
    /// Returns the content layout style for the given language code.
    public func contentLayout(forLanguage language: String?) -> ContentLayout {
        let language = (language?.isEmpty ?? true) ? nil : language
        return ContentLayout(
            language: language ?? metadata.languages.first ?? "",
            readingProgression: metadata.readingProgression
        )
    }
    
    public init(format: Format = .unknown, formatVersion: String? = nil, positionListFactory: @escaping (Publication) -> [Locator] = { _ in [] }, context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], tableOfContents: [Link] = [], otherCollections: [PublicationCollection] = []) {
        self.format = format
        self.formatVersion = formatVersion
        self.context = context
        self.metadata = metadata
        self.links = links
        self.readingOrder = readingOrder
        self.resources = resources
        self.tableOfContents = tableOfContents
        self.otherCollections = otherCollections
        self.positionListFactory = positionListFactory
    }
    
    /// Parses a Readium Web Publication Manifest.
    /// https://readium.org/webpub-manifest/schema/publication.schema.json
    public init(json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        guard var json = JSONDictionary(json) else {
            throw JSONError.parsing(Publication.self)
        }
        
        self.context = parseArray(json.pop("@context"), allowingSingle: true)
        self.metadata = try Metadata(json: json.pop("metadata"), normalizeHref: normalizeHref)
        self.links = [Link](json: json.pop("links"), normalizeHref: normalizeHref)
        // `readingOrder` used to be `spine`, so we parse `spine` as a fallback.
        self.readingOrder = [Link](json: json.pop("readingOrder") ?? json.pop("spine"), normalizeHref: normalizeHref)
            .filter { $0.type != nil }
        self.resources = [Link](json: json.pop("resources"), normalizeHref: normalizeHref)
            .filter { $0.type != nil }
        self.tableOfContents = [Link](json: json.pop("toc"), normalizeHref: normalizeHref)
        
        // Parses sub-collections from remaining JSON properties.
        self.otherCollections = [PublicationCollection](json: json.json, normalizeHref: normalizeHref)
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "@context": encodeIfNotEmpty(context),
            "metadata": metadata.json,
            "links": links.json,
            "readingOrder": readingOrder.json,
            "resources": encodeIfNotEmpty(resources.json),
            "toc": encodeIfNotEmpty(tableOfContents.json),
        ], additional: otherCollections.json)
    }

    /// Returns the Manifest's data JSON representation.
    public var manifest: Data? {
        return serializeJSONData(json)
    }

    /// Replaces the links for the first found subcollection with the given role.
    /// If none is found, creates a new subcollection.
    func setCollectionLinks(_ links: [Link], forRole role: String) {
        if let collection = otherCollections.first(withRole: role) {
            collection.links = links
        } else {
            otherCollections.append(PublicationCollection(role: role, links: links))
        }
    }

    /// Sets the URL where this `Publication`'s RWPM manifest is served.
    public func setSelfLink(href: String) {
        links.removeAll { $0.rels.contains("self") }
        links.append(Link(
            href: href,
            type: "application/webpub+json",
            rel: "self"
        ))
    }

    /// Finds the first `Link` having the given `rel` in the publications's links.
    public func link(withRel rel: String) -> Link? {
        return link { $0.rels.contains(rel) }
    }
    
    /// Finds the first Link having the given `href` in the publication's links.
    public func link(withHref href: String) -> Link? {
        return link { $0.href == href }
    }
    
    /// Finds the first Link matching the given predicate in the publication's [Link] properties: `resources`, `readingOrder` and `links`.
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
        guard let link = link else {
            return nil
        }
        
        if let url = URL(string: link.href), url.scheme != nil {
            return url
        } else {
            var href = link.href
            if href.hasPrefix("/") {
                href = String(href.dropFirst())
            }
            return baseURL.map { $0.appendingPathComponent(href) }
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
            self = {
                for mimetype in mimetypes {
                    switch mimetype {
                    case "application/epub+zip", "application/oebps-package+xml":
                        return .epub
                    case "application/vnd.comicbook+zip", "application/x-cbr":
                        return .cbz
                    case "application/pdf", "application/pdf+lcp":
                        return .pdf
                    case "application/webpub+json", "application/audiobook+json":
                        return .webpub
                    default:
                        break
                    }
                }
                
                switch fileExtension?.lowercased() {
                case "epub":
                    return .epub
                case "cbz":
                    return .cbz
                case "pdf", "lcpdf":
                    return .pdf
                case "json":
                    return .webpub
                default:
                    return .unknown
                }
            }()
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
            func mimetype(of url: URL) -> String? {
                // `mimetype` file in a directory
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory)
                if isDirectory.boolValue {
                    return try? String(contentsOf: file.appendingPathComponent("mimetype"), encoding: String.Encoding.utf8)
                    // UTI
                } else if let extUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, file.pathExtension as CFString, nil)?.takeUnretainedValue() {
                    return UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)?.takeRetainedValue() as String?
                } else {
                    return nil
                }
            }
            
            var mimetypes = mimetypes
            if let mimetype = mimetype(of: file) {
                mimetypes.append(mimetype)
            }

            self.init(mimetypes: mimetypes, fileExtension: file.pathExtension)
        }
        
        @available(*, deprecated, renamed: "init(file:)")
        public init(url: URL) {
            self.init(file: url)
        }

    }
    
}


// MARK: - Deprecated API

extension Publication {
    
    @available(*, deprecated, renamed: "formatVersion")
    public var version: Double {
        get {
            guard let versionString = formatVersion,
                let version = Double(versionString) else
            {
                return 0
            }
            return version
        }
        set { formatVersion = String(newValue) }
    }

    @available(*, deprecated, renamed: "baseURL")
    public var baseUrl: URL? { return baseURL }
    
    @available(*, unavailable, message: "This is not used anymore, don't set it")
    public var updatedDate: Date { return Date() }
    
    @available(*, deprecated, message: "Check the publication's type using `format` instead")
    public var internalData: [String: String] {
        // The code in the testapp used to check a property in `publication.internalData["type"]` to know which kind of publication this is.
        // To avoid breaking any app, we reproduce this value here:
        return [
            "type": {
                switch format {
                case .epub:
                    return "epub"
                case .cbz:
                    return "cbz"
                case .pdf:
                    return "pdf"
                default:
                    return "unknown"
                }
            }()
        ]
    }

    @available(*, deprecated, renamed: "manifest")
    public var manifestCanonical: String {
        return String(data: manifest ?? Data(), encoding: .utf8) ?? ""
    }
    
    @available(*, deprecated, renamed: "init(json:)")
    public static func parse(pubDict: [String: Any]) throws -> Publication {
        return try Publication(json: pubDict, normalizeHref: { $0 })
    }
    
    @available(*, deprecated, renamed: "url(to:)")
    public func uriTo(link: Link?) -> URL? {
        return url(to: link)
    }
    
    @available(*, deprecated, renamed: "positions")
    public var positionList: [Locator] { positions }
    
    @available(*, deprecated, renamed: "positionsByResource")
    public var positionListByResource: [String: [Locator]] { positionsByResource }
    
}
