//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Represents a single Guided Navigation Object, as defined in the
/// Readium Guided Navigation specification.
///
/// https://readium.org/guided-navigation/
public struct GuidedNavigationObject: Hashable, Sendable {
    public typealias ID = String

    /// Unique identifier for this object, in the scope of the containing Guided
    /// Navigation Document.
    public let id: ID?

    /// References to resources referenced by the current Guided Navigation
    /// Object.
    public let refs: Refs?

    /// Textual equivalent of the resources or fragment of the resources
    /// referenced by the current Guided Navigation Object.
    public let text: Text?

    /// Convey the structural semantics of a publication.
    public let roles: [ContentRole]

    /// Text, audio or image description for the current Guided Navigation
    /// Object.
    public let description: Description?

    /// Items that are children of the containing Guided Navigation Object.
    public let children: [GuidedNavigationObject]

    public init?(
        id: ID? = nil,
        refs: Refs? = nil,
        text: Text? = nil,
        roles: [ContentRole] = [],
        description: Description? = nil,
        children: [GuidedNavigationObject] = []
    ) {
        guard refs != nil || text != nil || !children.isEmpty else {
            return nil
        }
        self.id = id
        self.refs = refs
        self.text = text
        self.roles = roles
        self.description = description
        self.children = children
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        guard let json = json as? [String: Any] else {
            if json == nil {
                return nil
            }
            warnings?.log("Invalid Guided Navigation Object", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        let refs = try Refs(json: json, warnings: warnings)
        let text = try Text(json: json["text"], warnings: warnings)
        let children = [GuidedNavigationObject](json: json["children"], warnings: warnings)

        guard refs != nil || text != nil || !children.isEmpty else {
            warnings?.log("Guided Navigation Object requires at least one of audioref, imgref, textref, videoref, text, or children", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        let description = try Description(json: json["description"], warnings: warnings)

        self.init(
            id: json["id"] as? String,
            refs: refs,
            text: text,
            roles: (json["role"] as? [String])?.map(ContentRole.init) ?? [],
            description: description,
            children: children
        )
    }

    /// Represents a collection of Guided Navigation References declared in a
    /// Readium Guided Navigation Object.
    public struct Refs: Hashable, Sendable {
        /// References a textual resource or a fragment of it.
        public let text: AnyURL?

        /// References an image or a fragment of it.
        public let img: AnyURL?

        /// References an audio resource or a fragment of it.
        public let audio: AnyURL?

        /// References a video clip or a fragment of it.
        public let video: AnyURL?

        public init?(
            text: AnyURL? = nil,
            img: AnyURL? = nil,
            audio: AnyURL? = nil,
            video: AnyURL? = nil
        ) {
            guard text != nil || img != nil || audio != nil || video != nil else {
                return nil
            }

            self.audio = audio
            self.img = img
            self.text = text
            self.video = video
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            guard let json = json as? [String: Any] else {
                if json == nil {
                    return nil
                }
                warnings?.log("Invalid Guided Navigation Refs", model: Self.self, source: json, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }
            let text = (json["textref"] as? String).flatMap(AnyURL.init(string:))
            let img = (json["imgref"] as? String).flatMap(AnyURL.init(string:))
            let audio = (json["audioref"] as? String).flatMap(AnyURL.init(string:))
            let video = (json["videoref"] as? String).flatMap(AnyURL.init(string:))

            self.init(text: text, img: img, audio: audio, video: video)
        }
    }

    /// Represents the text content of a Guided Navigation Object.
    ///
    /// Can be either a bare string (normalized to `plain`) or an object with
    /// `plain`, `ssml`, and `language` properties.
    public struct Text: Hashable, Sendable {
        public let plain: String?
        public let ssml: SSML?
        public let language: Language?

        public init?(
            plain: String? = nil,
            ssml: String? = nil,
            language: Language? = nil
        ) {
            guard plain?.isEmpty == false || ssml?.isEmpty == false else {
                return nil
            }
            self.plain = plain
            self.ssml = ssml
            self.language = language
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            if json == nil {
                return nil
            }
            if let string = json as? String {
                self.init(plain: string)
            } else if let obj = json as? [String: Any] {
                let plain = obj["plain"] as? String
                let ssml = obj["ssml"] as? String
                guard plain?.isEmpty == false || ssml?.isEmpty == false else {
                    warnings?.log("Guided Navigation String requires at least one of plain, or ssml", model: Self.self, source: json, severity: .moderate)
                    return nil
                }

                self.init(
                    plain: plain,
                    ssml: ssml,
                    language: (obj["language"] as? String).map { Language(code: .bcp47($0)) }
                )
            } else {
                warnings?.log("Invalid Guided Navigation Text", model: Self.self, source: json, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }
        }
    }

    /// Represents the description for a Guided Navigation object.
    public struct Description: Hashable, Sendable {
        /// References to resources referenced by this description.
        public let refs: Refs?

        /// Textual equivalent of the resources or fragment of the resources
        /// referenced by this description.
        public let text: Text?

        public init?(
            refs: Refs? = nil,
            text: Text? = nil
        ) {
            guard refs != nil || text != nil else {
                return nil
            }
            self.refs = refs
            self.text = text
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            guard let json = json as? [String: Any] else {
                if json == nil {
                    return nil
                }
                warnings?.log("Invalid Guided Navigation Description", model: Self.self, source: json, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }

            let refs = try Refs(json: json, warnings: warnings)
            let text = try Text(json: json["text"], warnings: warnings)

            guard refs != nil || text != nil else {
                warnings?.log("Guided Navigation Description requires at least one of audioref, imgref, textref, videoref, or text", model: Self.self, source: json, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }

            self.init(refs: refs, text: text)
        }
    }
}

// MARK: - Array Extension

public extension Array where Element == GuidedNavigationObject {
    init(json: Any?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json as? [Any] else {
            return
        }
        let objects = json.compactMap { try? GuidedNavigationObject(json: $0, warnings: warnings) }
        append(contentsOf: objects)
    }
}
