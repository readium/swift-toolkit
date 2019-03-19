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

import Foundation


/// Shared model for a Readium Publication.
///
/// It extends the Web Publication model, which holds the metadata and resources.
/// On top of that, the Publication holds:
///   - the publication state used by the Streamer and Navigator
///   - shortcuts to various publication resources to be used by the Streamer and Navigator
///   - additional metadata not part of the RWPM
public class Publication: WebPublication, Loggable {
    
    /// MIME type of the publication.
    public var type: String?
    /// Version of the publication's format, eg. 3 for EPUB 3
    public var formatVersion: String?
    
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
    
    public init(type: String? = nil, formatVersion: String? = nil, context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], toc: [Link] = [], otherCollections: [PublicationCollection] = []) {
        self.type = type
        self.formatVersion = formatVersion
        super.init(context: context, metadata: metadata, links: links, readingOrder: readingOrder, resources: resources, toc: toc, otherCollections: otherCollections)
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

    @available(*, deprecated, renamed: "toc")
    public var tableOfContents: [Link] { get { return toc } set { toc = newValue } }
    
    @available(*, deprecated, renamed: "baseURL")
    public var baseUrl: URL? { return baseURL }
    
    @available(*, unavailable, message: "This is not used anymore, don't set it")
    public var updatedDate: Date { return Date() }
    
    @available(*, deprecated, message: "Check the publication's type using `type` instead (Warning: this is a MIME type and not a string like `epub`)")
    public var internalData: [String: String] {
        // The code in the testapp used to check a property in `publication.internalData["type"]` to know which kind of publication this is.
        // To avoid breaking any app, we reproduce this value here:
        return [
            "type": {
                switch type {
                case "application/epub+zip":
                    return "epub"
                case "application/x-cbr":
                    return "cbz"
                case "application/pdf":
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
