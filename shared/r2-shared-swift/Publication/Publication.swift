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
///
/// It extends the Web Publication model, which holds the metadata and resources.
/// On top of that, the Publication holds:
///   - the publication state used by the Streamer and Navigator
///   - shortcuts to various publication resources to be used by the Streamer and Navigator
///   - additional metadata not part of the RWPM
public class Publication: WebPublication, Loggable {

    /// Format of the publication, if specified.
    public var format: Format = .unknown
    /// Version of the publication's format, eg. 3 for EPUB 3
    public var formatVersion: String?

    /// Factory used to build lazily the `positionList`.
    /// By default, a parser will set this to parse the `positionList` from the publication. But the host app might want to overwrite this with a custom closure to implement for example a cache mechanism.
    public var positionListFactory: (Publication) -> [Locator] = { _ in [] }
    
    /// List of all the positions in the publication.
    public lazy var positionList: [Locator] = positionListFactory(self)
    
    /// List of all the positions in each resource, indexed by their `href`.
    public lazy var positionListByResource: [String: [Locator]] = positionList
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
    public var contentLayout: ContentLayoutStyle {
        return contentLayout(forLanguage: nil)
    }
    
    /// Returns the content layout style for the given language code.
    public func contentLayout(forLanguage language: String?) -> ContentLayoutStyle {
        let language = (language?.isEmpty ?? true) ? nil : language
        return ContentLayoutStyle(
            language: language ?? metadata.languages.first ?? "",
            readingProgression: metadata.readingProgression
        )
    }
    
    public init(format: Format = .unknown, formatVersion: String? = nil, positionListFactory: @escaping (Publication) -> [Locator] = { _ in [] }, context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], tableOfContents: [Link] = [], otherCollections: [PublicationCollection] = []) {
        self.format = format
        self.formatVersion = formatVersion
        self.positionListFactory = positionListFactory
        super.init(context: context, metadata: metadata, links: links, readingOrder: readingOrder, resources: resources, tableOfContents: tableOfContents, otherCollections: otherCollections)
    }
    
    public override init(json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        try super.init(json: json, normalizeHref: normalizeHref)
    }

    /// Appends the self/manifest link to links.
    ///
    /// - Parameters:
    ///   - endPoint: The URI prefix to use to fetch assets from the publication.
    ///   - baseUrl: The base URL of the HTTP server.
    public func addSelfLink(endpoint: String, for baseURL: URL) {
        // Removes any existing `self` link, just in case.
        links.removeAll { $0.rels.contains("self") }
        
        let manifestURL = baseURL.appendingPathComponent("\(endpoint)/manifest.json")
        links.append(Link(
            href: manifestURL.absoluteString,
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
    /// - Parameter path: The relative path to the resource (href)
    public func resource(withRelativePath path: String) -> Link? {
        return readingOrder.first(withHref: path)
            ?? resources.first(withHref: path)
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
        guard let link = link, let baseURL = self.baseURL else {
            return nil
        }
        
        // Remove trailing "/" before appending the href (href are absolute, hence starting with a "/", but relative to the publication).
        let trimmedBaseURLString = baseURL.absoluteString.trimmingCharacters(in: ["/"])
        
        return URL(string: trimmedBaseURLString)?
            .appendingPathComponent(link.href)
    }
    
    
    public enum Format: Equatable, Hashable {
        /// Formats natively supported by Readium.
        case cbz, epub, pdf
        /// Custom format extension (MIME type)
        case other(String)
        /// Default value when the format is not specified.
        case unknown
        
        /// Finds the format for a given mimetype.
        public init(mimetype: String?) {
            guard let mimetype = mimetype else {
                self = .unknown
                return
            }
            
            switch mimetype {
            case "application/epub+zip", "application/oebps-package+xml":
                self = .epub
            case "application/x-cbr":
                self = .cbz
            case "application/pdf", "application/pdf+lcp":
                self = .pdf
            default:
                self = .other(mimetype)
            }
        }
        
        /// Finds the format of the publication at the given url.
        /// Uses the format declared as exported UTIs in the app's Info.plist, or fallbacks on the file extension.
        public init(file: URL) {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory) else {
                self = .unknown
                return
            }
            
            var mimetype: String?
            if isDirectory.boolValue {
                mimetype = try? String(contentsOf: file.appendingPathComponent("mimetype"), encoding: String.Encoding.utf8)
            } else if let extUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, file.pathExtension as CFString, nil)?.takeUnretainedValue() {
                mimetype = UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)?.takeRetainedValue() as String?
            }
            
            if let unwrappedMimetype = mimetype {
                self.init(mimetype: unwrappedMimetype)
                return
            }
            
            switch file.pathExtension.lowercased() {
            case "epub":
                self = .epub
            case "cbz":
                self = .cbz
            case "pdf", "lpdf":
                self = .pdf
            default:
                self = .unknown
            }
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
    
}
