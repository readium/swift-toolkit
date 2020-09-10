//
//  Publication+Deprecated.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

@available(*, deprecated, renamed: "Publication")
public typealias WebPublication = Publication

extension Publication {
    
    @available(*, deprecated, renamed: "init(metadata:)")
    public convenience init() {
        self.init(metadata: Metadata(title: ""))
    }
    
    @available(*, deprecated, renamed: "resource(withHref:)")
    public func resource(withRelativePath path: String) -> Link? {
        return resource(withHref: path)
    }
    
    @available(*, deprecated, message: "Use `setSelfLink` instead")
    public func addSelfLink(endpoint: String, for baseURL: URL) {
        let manifestURL = baseURL.appendingPathComponent("\(endpoint)/manifest.json")
        setSelfLink(href: manifestURL.absoluteString)
    }
    
    @available(*, unavailable, message: "`Publication` is now immutable")
    func setCollectionLinks(_ links: [Link], forRole role: String) {}

}

extension Publication {
    
    @available(*, deprecated, renamed: "listOfAudioClips")
    public var listOfAudioFiles: [Link] { listOfAudioClips }
    
    @available(*, deprecated, renamed: "listOfVideoClips")
    public var listOfVideos: [Link] { listOfVideoClips }
    
}

@available(*, deprecated, renamed: "LocalizedString")
public typealias MultilangString = LocalizedString

extension LocalizedString {
    
    @available(*, deprecated, message: "Get with the property `string`")
    public var singleString: String? {
        string.isEmpty ? nil : string
    }
    
    @available(*, deprecated, message: "Get with `string(forLanguageCode:)`")
    public var multiString: [String: String] {
        guard case .localized(let strings) = self else {
            return [:]
        }
        return strings
    }
    
    @available(*, deprecated, renamed: "LocalizedString.localized")
    public init() {
        self = .localized([:])
    }

}

extension Metadata {
    
    @available(*, deprecated, renamed: "type")
    public var rdfType: String? { type }

    @available(*, deprecated, renamed: "localizedTitle")
    public var multilangTitle: LocalizedString { localizedTitle }

    @available(*, deprecated, renamed: "localizedSubtitle")
    public var multilangSubtitle: LocalizedString? { localizedSubtitle }

    @available(*, unavailable, message: "Not used anymore, you can store the rights in `otherMetadata[\"rights\"]` if necessary")
    public var rights: String? { nil }
    
    @available(*, unavailable, message: "Not used anymore, you can store the source in `otherMetadata[\"source\"]` if necessary")
    public var source: String? { nil }
    
    @available(*, deprecated, renamed: "init(title:)")
    public init() {
        self.init(title: "")
    }
    
    @available(*, deprecated, message: "Use `localizedTitle.string(forLanguageCode:)` instead")
    public func titleForLang(_ lang: String) -> String? {
        return localizedTitle.string(forLanguageCode: lang)
    }
    
    @available(*, deprecated, message: "Use `localizedSubtitle.string(forLanguageCode:)` instead")
    public func subtitleForLang(_ lang: String) -> String? {
        return localizedSubtitle?.string(forLanguageCode: lang)
    }
    
    @available(*, deprecated, renamed: "init(json:)")
    public static func parse(metadataDict: [String: Any]) throws -> Metadata {
        return try Metadata(json: metadataDict, normalizeHref: { $0 })
    }
    
    @available(*, deprecated, renamed: "presentation")
    public var rendition: EPUBRendition { presentation }
    
}

extension Contributor {
    
    @available(*, deprecated, renamed: "localizedName")
    public var multilangName: LocalizedString { localizedName }

    @available(*, deprecated, renamed: "init(name:)")
    public init() {
        self.init(name: "")
    }
    
    @available(*, deprecated, renamed: "init(json:)")
    public static func parse(_ cDict: [String: Any]) throws -> Contributor {
        return try Contributor(json: cDict, normalizeHref: { $0 })
    }
    
    @available(*, deprecated, message: "Use `[Contributor](json:)` instead")
    public static func parse(contributors: Any) throws -> [Contributor] {
        return [Contributor](json: contributors, normalizeHref: { $0 })
    }
    
}

extension Subject {
    
    @available(*, deprecated, renamed: "init(name:)")
    public init() {
        self.init(name: "")
    }
    
}

extension Link {
    
    @available(*, deprecated, renamed: "type")
    public var typeLink: String? { type }
    
    @available(*, deprecated, renamed: "rels")
    public var rel: [String] { rels }
    
    @available(*, deprecated, renamed: "href")
    public var absoluteHref: String? { href }
    
    @available(*, deprecated, renamed: "init(href:)")
    public init() {
        self.init(href: "")
    }
    
    @available(*, deprecated, renamed: "init(json:)")
    static public func parse(linkDict: [String: Any]) throws -> Link {
        return try Link(json: linkDict, normalizeHref: { $0 })
    }
    
    @available(*, unavailable, message: "The media overlay API was only half implemented and will be refactored later")
    public var mediaOverlays: MediaOverlays { MediaOverlays() }
    
}

extension Properties {

    @available(*, deprecated, renamed: "Presentation.Orientation")
    public typealias Orientation = Presentation.Orientation
    
    @available(*, deprecated, renamed: "Presentation.Page")
    public typealias Page = Presentation.Page
    
    @available(*, deprecated, renamed: "indirectAcquisitions")
    public var indirectAcquisition: [OPDSAcquisition] {
        indirectAcquisitions
    }
    
    @available(*, unavailable, message: "The media overlay API was only half implemented and will be refactored later")
    public var mediaOverlay: String? { nil }
    
    @available(*, unavailable, message: "`Properties` is now immutable")
    mutating func setProperty<T: RawRepresentable>(_ value: T?, forKey key: String) {}
    
    @available(*, unavailable, message: "`Properties` is now immutable")
    mutating func setProperty<T: Collection>(_ value: T?, forKey key: String) {}

}

extension Presentation {
    
    @available(*, deprecated, renamed: "EPUBLayout")
    public typealias Layout = EPUBLayout
    
}

@available(*, deprecated, renamed: "OPDSPrice")
public typealias Price = OPDSPrice

@available(*, deprecated, renamed: "OPDSAcquisition")
public typealias IndirectAcquisition = OPDSAcquisition

extension OPDSAcquisition {

    @available(*, deprecated, renamed: "type")
    public var typeAcquisition: String { type }
    
    @available(*, deprecated, renamed: "children")
    public var child: [OPDSAcquisition] { children }
    
}

@available(*, deprecated, renamed: "ContentLayout")
public typealias ContentLayoutStyle = ContentLayout

@available(*, deprecated, renamed: "Presentation")
public typealias EPUBRendition = Presentation

@available(*, deprecated, renamed: "Encryption")
public typealias EPUBEncryption = Encryption

@available(*, deprecated, renamed: "Locator.Locations")
public typealias Locations = Locator.Locations

@available(*, deprecated, renamed: "Locator.Text")
public typealias LocatorText = Locator.Text
