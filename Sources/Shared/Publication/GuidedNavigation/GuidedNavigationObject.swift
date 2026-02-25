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
    public let roles: [Role]

    /// Text, audio or image description for the current Guided Navigation
    /// Object.
    public let description: Description?

    /// Items that are children of the containing Guided Navigation Object.
    public let children: [GuidedNavigationObject]

    public init?(
        id: ID? = nil,
        refs: Refs? = nil,
        text: Text? = nil,
        roles: [Role] = [],
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

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let jsonDict = JSONDictionary(json) else {
            if json == nil {
                return nil
            }
            warnings?.log("Invalid Guided Navigation Object", model: Self.self, source: json?.any, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
        let jsonObject = jsonDict.json

        let refs = try Refs(json: json, warnings: warnings)
        let text = try Text(json: jsonObject["text"], warnings: warnings)
        let children = [GuidedNavigationObject](json: jsonObject["children"], warnings: warnings)

        guard refs != nil || text != nil || !children.isEmpty else {
            warnings?.log("Guided Navigation Object requires at least one of audioref, imgref, textref, videoref, text, or children", model: Self.self, source: json?.any, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        let description = try Description(json: jsonObject["description"], warnings: warnings)

        self.init(
            id: jsonObject["id"]?.string,
            refs: refs,
            text: text,
            roles: parseArray(jsonObject["role"]).map(Role.init),
            description: description,
            children: children
        )
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        try self.init(json: JSONValue(json), warnings: warnings)
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

        public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
            guard let jsonDict = JSONDictionary(json) else {
                if json == nil {
                    return nil
                }
                warnings?.log("Invalid Guided Navigation Refs", model: Self.self, source: json?.any, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }
            let json = jsonDict.json
            let text = json["textref"]?.string.flatMap(AnyURL.init(string:))
            let img = json["imgref"]?.string.flatMap(AnyURL.init(string:))
            let audio = json["audioref"]?.string.flatMap(AnyURL.init(string:))
            let video = json["videoref"]?.string.flatMap(AnyURL.init(string:))

            self.init(text: text, img: img, audio: audio, video: video)
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            try self.init(json: JSONValue(json), warnings: warnings)
        }
    }

    /// Represents the text content of a Guided Navigation Object.
    ///
    /// Can be either a bare string (normalized to `plain`) or an object with
    /// `plain`, `ssml`, and `language` properties.
    public struct Text: Hashable, Sendable {
        public let plain: String?
        public let ssml: String?
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

        public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
            guard let json = json else {
                return nil
            }
            if let string = json.string {
                self.init(plain: string)
            } else if let obj = json.object {
                let plain = obj["plain"]?.string
                let ssml = obj["ssml"]?.string
                guard plain?.isEmpty == false || ssml?.isEmpty == false else {
                    warnings?.log("Guided Navigation String requires at least one of plain, or ssml", model: Self.self, source: json.any, severity: .moderate)
                    return nil
                }

                self.init(
                    plain: plain,
                    ssml: ssml,
                    language: obj["language"]?.string.map { Language(code: .bcp47($0)) }
                )
            } else {
                warnings?.log("Invalid Guided Navigation Text", model: Self.self, source: json.any, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            try self.init(json: JSONValue(json), warnings: warnings)
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

        public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
            guard let jsonDict = JSONDictionary(json) else {
                if json == nil {
                    return nil
                }
                warnings?.log("Invalid Guided Navigation Description", model: Self.self, source: json?.any, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }

            let refs = try Refs(json: json, warnings: warnings)
            let text = try Text(json: jsonDict["text"], warnings: warnings)

            guard refs != nil || text != nil else {
                warnings?.log("Guided Navigation Description requires at least one of audioref, imgref, textref, videoref, or text", model: Self.self, source: json?.any, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }

            self.init(refs: refs, text: text)
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            try self.init(json: JSONValue(json), warnings: warnings)
        }
    }

    /// Represents a role for a Guided Navigation Object.
    ///
    /// See https://readium.org/guided-navigation/roles
    public struct Role: Hashable, Sendable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        /// A sequential container for objects and/or child containers.
        public static let sequence = Role("sequence")

        // MARK: Inherited from DPUB ARIA 1.0

        /// A short summary of the principle ideas, concepts and conclusions of
        /// the work, or of a section or excerpt within it.
        public static let abstract = Role("abstract")

        /// A section or statement that acknowledges significant contributions
        /// by persons, organizations, governments and other entities to the
        /// realization of the work.
        public static let acknowledgments = Role("acknowledgments")

        /// A closing statement from the author or a person of importance,
        /// typically providing insight into how the content came to be written.
        public static let afterword = Role("afterword")

        /// A section of supplemental information located after the primary
        /// content that informs the content but is not central to it.
        public static let appendix = Role("appendix")

        /// A link that allows the user to return to a related location in the
        /// content (e.g., from a footnote to its reference or from a glossary
        /// definition to where a term is used).
        public static let backlink = Role("backlink")

        /// A list of external references cited in the work, which may be to
        /// print or digital sources.
        public static let bibliography = Role("bibliography")

        /// A reference to a bibliography entry.
        public static let biblioref = Role("biblioref")

        /// A major thematic section of content in a work.
        public static let chapter = Role("chapter")

        /// A short section of production notes particular to the edition
        /// (e.g., describing the typeface used), often located at the end of a
        /// work.
        public static let colophon = Role("colophon")

        /// A concluding section or statement that summarizes the work or wraps
        /// up the narrative.
        public static let conclusion = Role("conclusion")

        /// An image that sets the mood or tone for the work and typically
        /// includes the title and author.
        public static let cover = Role("cover")

        /// An acknowledgment of the source of integrated content from
        /// third-party sources, such as photos.
        public static let credit = Role("credit")

        /// A collection of credits.
        public static let credits = Role("credits")

        /// An inscription at the front of the work, typically addressed in
        /// tribute to one or more persons close to the author.
        public static let dedication = Role("dedication")

        /// A collection of notes at the end of a work or a section within it.
        public static let endnotes = Role("endnotes")

        /// A quotation set at the start of the work or a section that
        /// establishes the theme or sets the mood.
        public static let epigraph = Role("epigraph")

        /// A concluding section of narrative that wraps up or comments on the
        /// actions and events of the work, typically from a future perspective.
        public static let epilogue = Role("epilogue")

        /// A set of corrections discovered after initial publication of the
        /// work, sometimes referred to as corrigenda.
        public static let errata = Role("errata")

        /// An illustration of the usage of a defined term or phrase.
        public static let example = Role("example")

        /// Ancillary information, such as a citation or commentary, that
        /// provides additional context to a referenced passage of text.
        public static let footnote = Role("footnote")

        /// A brief dictionary of new, uncommon, or specialized terms used in
        /// the content.
        public static let glossary = Role("glossary")

        /// A reference to a glossary definition.
        public static let glossref = Role("glossref")

        /// A navigational aid that provides a detailed list of links to key
        /// subjects, names and other important topics covered in the work.
        public static let index = Role("index")

        /// A preliminary section that typically introduces the scope or nature
        /// of the work.
        public static let introduction = Role("introduction")

        /// A reference to a footnote or endnote, typically appearing as a
        /// superscripted number or symbol in the main body of text.
        public static let noteref = Role("noteref")

        /// Notifies the user of consequences that might arise from an action
        /// or event. Examples include warnings, cautions and dangers.
        public static let notice = Role("notice")

        /// A separator denoting the position before which a break occurs
        /// between two contiguous pages in a statically paginated version of
        /// the content.
        public static let pagebreak = Role("pagebreak")

        /// A navigational aid that provides a list of links to the pagebreaks
        /// in the content.
        public static let pagelist = Role("pagelist")

        /// A major structural division in a work that contains a set of
        /// related sections dealing with a particular subject, narrative arc or
        /// similar encapsulated theme.
        public static let part = Role("part")

        /// An introductory section that precedes the work, typically written by
        /// the author of the work.
        public static let preface = Role("preface")

        /// An introductory section that sets the background to a work,
        /// typically part of the narrative.
        public static let prologue = Role("prologue")

        /// A distinctively placed or highlighted quotation from the current
        /// content designed to draw attention to a topic or highlight a key
        /// point.
        public static let pullquote = Role("pullquote")

        /// A section of content structured as a series of questions and
        /// answers, such as an interview or list of frequently asked questions.
        public static let qna = Role("qna")

        /// An explanatory or alternate title for the work, or a section or
        /// component within it.
        public static let subtitle = Role("subtitle")

        /// Helpful information that clarifies some aspect of the content or
        /// assists in its comprehension.
        public static let tip = Role("tip")

        /// A navigational aid that provides an ordered list of links to the
        /// major sectional headings in the content.
        public static let toc = Role("toc")

        // MARK: Inherited from HTML and/or ARIA

        /// A self-contained composition in a document, page, application, or
        /// site, which is intended to be independently distributable or
        /// reusable.
        public static let article = Role("article")

        /// Secondary or supplementary content.
        public static let aside = Role("aside")

        /// Embedded sound content in a document.
        public static let audio = Role("audio")

        /// A section that is quoted from another source.
        public static let blockquote = Role("blockquote")

        /// Represents the content of an HTML document.
        public static let body = Role("body")

        /// A caption for an image or a table.
        public static let caption = Role("caption")

        /// A single cell of tabular data or content.
        public static let cell = Role("cell")

        /// The header cell for a column, establishing a relationship between
        /// it and the other cells in the same column.
        public static let columnheader = Role("columnheader")

        /// A supporting section of the document, designed to be complementary
        /// to the main content at a similar level in the DOM hierarchy.
        public static let complementary = Role("complementary")

        /// A definition of a term or concept.
        public static let definition = Role("definition")

        /// A disclosure widget that can be expanded.
        public static let details = Role("details")

        /// An illustration, diagram, photo, code listing or similar,
        /// referenced from the text of a work, and typically annotated with a
        /// title, caption and/or credits.
        public static let figure = Role("figure")

        /// Introductory content, typically a group of introductory or
        /// navigational aids.
        public static let header = Role("header")

        /// A heading for a section of the page.
        public static let heading1 = Role("heading1")

        /// A heading for a section of the page.
        public static let heading2 = Role("heading2")

        /// A heading for a section of the page.
        public static let heading3 = Role("heading3")

        /// A heading for a section of the page.
        public static let heading4 = Role("heading4")

        /// A heading for a section of the page.
        public static let heading5 = Role("heading5")

        /// A heading for a section of the page.
        public static let heading6 = Role("heading6")

        /// An image.
        public static let image = Role("image")

        /// A structure that contains an enumeration of related content items.
        public static let list = Role("list")

        /// A single item in an enumeration.
        public static let listItem = Role("listItem")

        /// Content that is directly related to or expands upon the central
        /// topic of the document.
        public static let main = Role("main")

        /// Content that represents a mathematical expression.
        public static let math = Role("math")

        /// A section of a page that links to other pages or to parts within
        /// the page.
        public static let navigation = Role("navigation")

        /// A paragraph.
        public static let paragraph = Role("paragraph")

        /// Preformatted text which is to be presented exactly as written.
        public static let preformatted = Role("preformatted")

        /// An element being used only for presentation and therefore that does
        /// not have any accessibility semantics.
        public static let presentation = Role("presentation")

        /// Content that is relevant to a specific, author-specified purpose
        /// and sufficiently important that users will likely want to be able to
        /// navigate to the section easily.
        public static let region = Role("region")

        /// A row of data or content in a tabular structure.
        public static let row = Role("row")

        /// The header cell for a row, establishing a relationship between it
        /// and the other cells in the same row.
        public static let rowheader = Role("rowheader")

        /// A generic standalone section of a document, which doesn't have a
        /// more specific semantic element to represent it.
        public static let section = Role("section")

        /// A divider that separates and distinguishes sections of content or
        /// groups of menu items.
        public static let separator = Role("separator")

        /// A summary of an element contained in details.
        public static let summary = Role("summary")

        /// A structure containing data or content laid out in tabular form.
        public static let table = Role("table")

        /// A word or phrase with a corresponding definition.
        public static let term = Role("term")

        /// Embedded videos, movies, or audio files with captions in a
        /// document.
        public static let video = Role("video")

        // MARK: Inherited from EPUB SSV 1.1

        /// An area in a comic panel that contains the words, spoken or thought,
        /// of a character.
        public static let bubble = Role("bubble")

        /// An introductory section that precedes the work, typically not
        /// written by the author of the work.
        public static let foreword = Role("foreword")

        /// A collection of references to audio clips.
        public static let landmarks = Role("landmarks")

        /// A listing of audio clips included in the work.
        public static let loa = Role("loa")

        /// A listing of illustrations included in the work.
        public static let loi = Role("loi")

        /// A listing of tables included in the work.
        public static let lot = Role("lot")

        /// A listing of video clips included in the work.
        public static let lov = Role("lov")

        /// An individual frame, or drawing.
        public static let panel = Role("panel")

        /// A group of panels (e.g., a strip).
        public static let panelGroup = Role("panelGroup")

        /// An area of text in a comic panel that represents a sound.
        public static let sound = Role("sound")
    }
}

// MARK: - Array Extension

public extension Array where Element == GuidedNavigationObject {
    init(json: JSONValue?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json?.array else {
            return
        }
        let objects = json.compactMap { try? GuidedNavigationObject(json: $0, warnings: warnings) }
        append(contentsOf: objects)
    }

    init(json: Any?, warnings: WarningLogger? = nil) {
        self.init(json: JSONValue(json), warnings: warnings)
    }
}
