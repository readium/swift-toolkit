//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// https://github.com/readium/architecture/tree/master/locators
public struct Locator: Hashable, CustomStringConvertible, Loggable, Sendable, JSONValueDecodable, JSONObjectEncodable {
    /// The URI of the resource that the Locator Object points to.
    public var href: AnyURL

    /// The media type of the resource that the Locator Object points to.
    public var mediaType: MediaType

    /// The title of the chapter or section which is more relevant in the context of this locator.
    public var title: String?

    /// One or more alternative expressions of the location.
    public var locations: Locations

    /// Textual context of the locator.
    public var text: Text

    public init<T: URLConvertible>(href: T, mediaType: MediaType, title: String? = nil, locations: Locations = .init(), text: Text = .init()) {
        self.href = href.anyURL
        self.mediaType = mediaType
        self.title = title
        self.locations = locations
        self.text = text
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        try self.init(json: json, warnings: warnings, legacyHREF: false)
    }

    /// Creates a ``Locator`` from its legacy JSON representation.
    ///
    /// Only use this API when you are upgrading to Readium 3.x and migrating
    /// the ``Locator`` objects stored in your database. See the migration guide
    /// for more information.
    public init?(legacyJSONString: String, warnings: WarningLogger? = nil) throws {
        let json = try JSONValue(jsonString: legacyJSONString, warnings: warnings)
        try self.init(json: json, warnings: warnings, legacyHREF: true)
    }

    private init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?, legacyHREF: Bool) throws {
        guard let json = json?.jsonValue else {
            return nil
        }
        guard let jsonObject = json.object,
              let hrefString = jsonObject["href"]?.string,
              let typeString = jsonObject["type"]?.string
        else {
            warnings?.log("`href` and `type` required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        guard let type = MediaType(typeString) else {
            warnings?.log("`type` is not a valid media type", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        guard let href = legacyHREF ? AnyURL(legacyHREF: hrefString) : AnyURL(string: hrefString) else {
            warnings?.log("`href` is not a valid URL", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        try self.init(
            href: href,
            mediaType: type,
            title: jsonObject["title"]?.string,
            locations: Locations(json: jsonObject["locations"], warnings: warnings) ?? Locations(),
            text: Text(json: jsonObject["text"], warnings: warnings) ?? Text()
        )
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "href": href.string,
            "type": mediaType.string,
            "title": title,
            "locations": locations.orNullIfEmpty,
            "text": text.orNullIfEmpty,
        ])
    }

    public var description: String {
        (try? jsonString()) ?? "{}"
    }

    /// Makes a copy of the `Locator`, after modifying some of its components.
    public func copy(
        href: AnyURL? = nil,
        mediaType: MediaType? = nil,
        title: String?? = nil,
        locations transformLocations: ((inout Locations) -> Void)? = nil,
        text transformText: ((inout Text) -> Void)? = nil
    ) -> Locator {
        var locations = locations
        var text = text
        transformLocations?(&locations)
        transformText?(&text)
        return Locator(
            href: href ?? self.href,
            mediaType: mediaType ?? self.mediaType,
            title: title ?? self.title,
            locations: locations,
            text: text
        )
    }

    /// Makes a copy of the `Locator`, after modifying some of its components.
    public func copy<T: URLConvertible>(
        href: T?,
        mediaType: MediaType? = nil,
        title: String?? = nil,
        locations: ((inout Locations) -> Void)? = nil,
        text: ((inout Text) -> Void)? = nil
    ) -> Locator {
        copy(
            href: href?.anyURL,
            mediaType: mediaType,
            title: title,
            locations: locations,
            text: text
        )
    }

    /// One or more alternative expressions of the location.
    /// https://github.com/readium/architecture/tree/master/models/locators#the-location-object
    ///
    /// Properties are mutable for convenience when making a copy, but the `locations` property
    /// is immutable in `Locator`, for safety.
    public struct Locations: Hashable, Loggable, WarningLogger, Sendable, JSONValueDecodable, JSONObjectEncodable {
        /// Contains one or more fragment in the resource referenced by the `Locator`.
        public var fragments: [String]
        /// Progression in the resource expressed as a percentage (between 0 and 1).
        public var progression: Double?
        /// Progression in the publication expressed as a percentage (between 0 and 1).
        public var totalProgression: Double?
        /// An index in the publication (>= 1).
        public var position: Int?

        /// Additional locations for extensions.
        public var otherLocations: [String: JSONValue]

        public init(fragments: [String] = [], progression: Double? = nil, totalProgression: Double? = nil, position: Int? = nil, otherLocations: [String: JSONValue] = [:]) {
            self.fragments = fragments
            self.progression = progression
            self.totalProgression = totalProgression
            self.position = position
            self.otherLocations = otherLocations
        }

        public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
            guard let json = json?.jsonValue else {
                return nil
            }
            guard var jsonObject = json.object else {
                warnings?.log("Invalid Locations object", model: Self.self, source: json)
                throw JSONError.parsing(Self.self)
            }
            var fragments: [String] = jsonObject.pop("fragments")?.decode() ?? []
            if let fragment = jsonObject.pop("fragment")?.string {
                fragments.append(fragment)
            }
            self.init(
                fragments: fragments,
                progression: jsonObject.pop("progression")?.double,
                totalProgression: jsonObject.pop("totalProgression")?.double,
                position: jsonObject.pop("position")?.nonNegative(),
                otherLocations: jsonObject
            )
        }

        public var isEmpty: Bool {
            jsonObject.isEmpty
        }

        public var jsonObject: [String: JSONValue] {
            .init([
                "fragments": fragments.orNullIfEmpty,
                "progression": progression,
                "totalProgression": totalProgression,
                "position": position,
            ], adding: otherLocations)
        }

        /// Syntactic sugar to access the `otherLocations` values by subscripting `Locations` directly.
        /// locations["cssSelector"] == locations.otherLocations["cssSelector"]
        public subscript(key: String) -> JSONValue? {
            otherLocations[key]
        }
    }

    public struct Text: Hashable, Loggable, Sendable, JSONValueDecodable, JSONObjectEncodable {
        public var after: String?
        public var before: String?
        public var highlight: String?

        public init(after: String? = nil, before: String? = nil, highlight: String? = nil) {
            self.after = after
            self.before = before
            self.highlight = highlight
        }

        public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
            guard let json = json?.jsonValue else {
                return nil
            }
            guard let jsonObject = json.object else {
                warnings?.log("Invalid Text object", model: Self.self, source: json)
                throw JSONError.parsing(Self.self)
            }
            self.init(
                after: jsonObject["after"]?.string,
                before: jsonObject["before"]?.string,
                highlight: jsonObject["highlight"]?.string
            )
        }

        public var jsonObject: [String: JSONValue] {
            .init([
                "after": after,
                "before": before,
                "highlight": highlight,
            ])
        }

        /// Returns a copy of this text after sanitizing its content for user display.
        public func sanitized() -> Locator.Text {
            Locator.Text(
                after: after?.coalescingWhitespaces().removingSuffix(" "),
                before: before?.coalescingWhitespaces().removingPrefix(" "),
                highlight: highlight?.coalescingWhitespaces()
            )
        }

        /// Returns a copy of this text after highlighting a sub-range in the `highlight` property.
        ///
        /// The bounds of the range must be valid indices of the `highlight` property.
        public subscript(range: Range<String.Index>) -> Text {
            guard
                let highlight = highlight,
                !highlight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return Locator.Text(
                    after: after.takeIf { !$0.isEmpty },
                    before: before.takeIf { !$0.isEmpty },
                    highlight: nil
                )
            }

            let range = range
                .clamped(to: highlight.startIndex ..< highlight.endIndex)

            var before = before ?? ""
            var after = after ?? ""
            let newHighlight = highlight[range]
            before = before + highlight[..<range.lowerBound]
            after = highlight[range.upperBound...] + after

            return Locator.Text(
                after: Optional(after).takeIf { !$0.isEmpty },
                before: Optional(before).takeIf { !$0.isEmpty },
                highlight: String(newHighlight)
            )
        }
    }
}

/// Represents a sequential list of `Locator` objects.
///
/// For example, a search result or a list of positions.
public struct LocatorCollection: Sendable, Hashable, JSONValueDecodable, JSONObjectEncodable {
    public var metadata: Metadata
    public var links: [Link]
    public var locators: [Locator]

    public init(metadata: Metadata = Metadata(), links: [Link] = [], locators: [Locator] = []) {
        self.metadata = metadata
        self.links = links
        self.locators = locators
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }
        guard let jsonObject = json.object else {
            warnings?.log("Not a JSON object", model: Self.self, source: json)
            return nil
        }
        try self.init(
            metadata: Metadata(json: jsonObject["metadata"], warnings: warnings) ?? Metadata(),
            links: jsonObject["links"]?.decode(warnings: warnings) ?? [],
            locators: jsonObject["locators"]?.decode(warnings: warnings) ?? []
        )
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "metadata": metadata.orNullIfEmpty,
            "links": links.orNullIfEmpty,
            "locators": locators,
        ])
    }

    /// Holds the metadata of a `LocatorCollection`.
    public struct Metadata: Sendable, Hashable, JSONValueDecodable, JSONObjectEncodable {
        public var localizedTitle: LocalizedString?
        public var title: String? {
            localizedTitle?.string
        }

        /// Indicates the total number of locators in the collection.
        public var numberOfItems: Int?

        /// Additional properties for extensions.
        public var otherMetadata: [String: JSONValue]

        public init(
            title: LocalizedStringConvertible? = nil,
            numberOfItems: Int? = nil,
            otherMetadata: [String: JSONValue] = [:]
        ) {
            localizedTitle = title?.localizedString
            self.numberOfItems = numberOfItems
            self.otherMetadata = otherMetadata
        }

        public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
            guard let json = json?.jsonValue else {
                return nil
            }
            guard var jsonObject = json.object else {
                warnings?.log("Not a JSON object", model: Self.self, source: json)
                return nil
            }
            self.init(
                title: try? LocalizedString(json: jsonObject.pop("title"), warnings: warnings),
                numberOfItems: jsonObject.pop("numberOfItems")?.nonNegative(),
                otherMetadata: jsonObject
            )
        }

        public var jsonObject: [String: JSONValue] {
            .init([
                "title": localizedTitle,
                "numberOfItems": numberOfItems,
            ], adding: otherMetadata)
        }
    }
}
