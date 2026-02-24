//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Conveys the structural semantics of a piece of publication content.
///
/// Roles are inherited from multiple specifications such as HTML, ARIA,
/// DPUB ARIA and EPUB 3 Semantics Vocabulary.
///
/// See https://readium.org/guided-navigation/roles
public struct ContentRole: Hashable, Sendable {
    /// Unique identifier for this role.
    public let id: String

    /// Creates a custom role with the given identifier.
    public init(_ id: String) {
        self.id = id
    }

    /// A sequential container for objects and/or child containers.
    public static let sequence = ContentRole("sequence")

    // MARK: Inherited from DPUB ARIA 1.0

    /// A short summary of the principle ideas, concepts and conclusions of
    /// the work, or of a section or excerpt within it.
    public static let abstract = ContentRole("abstract")

    /// A section or statement that acknowledges significant contributions
    /// by persons, organizations, governments and other entities to the
    /// realization of the work.
    public static let acknowledgments = ContentRole("acknowledgments")

    /// A closing statement from the author or a person of importance,
    /// typically providing insight into how the content came to be written.
    public static let afterword = ContentRole("afterword")

    /// A section of supplemental information located after the primary
    /// content that informs the content but is not central to it.
    public static let appendix = ContentRole("appendix")

    /// A link that allows the user to return to a related location in the
    /// content (e.g., from a footnote to its reference or from a glossary
    /// definition to where a term is used).
    public static let backlink = ContentRole("backlink")

    /// A list of external references cited in the work, which may be to
    /// print or digital sources.
    public static let bibliography = ContentRole("bibliography")

    /// A reference to a bibliography entry.
    public static let biblioref = ContentRole("biblioref")

    /// A major thematic section of content in a work.
    public static let chapter = ContentRole("chapter")

    /// A short section of production notes particular to the edition
    /// (e.g., describing the typeface used), often located at the end of a
    /// work.
    public static let colophon = ContentRole("colophon")

    /// A concluding section or statement that summarizes the work or wraps
    /// up the narrative.
    public static let conclusion = ContentRole("conclusion")

    /// An image that sets the mood or tone for the work and typically
    /// includes the title and author.
    public static let cover = ContentRole("cover")

    /// An acknowledgment of the source of integrated content from
    /// third-party sources, such as photos.
    public static let credit = ContentRole("credit")

    /// A collection of credits.
    public static let credits = ContentRole("credits")

    /// An inscription at the front of the work, typically addressed in
    /// tribute to one or more persons close to the author.
    public static let dedication = ContentRole("dedication")

    /// A collection of notes at the end of a work or a section within it.
    public static let endnotes = ContentRole("endnotes")

    /// A quotation set at the start of the work or a section that
    /// establishes the theme or sets the mood.
    public static let epigraph = ContentRole("epigraph")

    /// A concluding section of narrative that wraps up or comments on the
    /// actions and events of the work, typically from a future perspective.
    public static let epilogue = ContentRole("epilogue")

    /// A set of corrections discovered after initial publication of the
    /// work, sometimes referred to as corrigenda.
    public static let errata = ContentRole("errata")

    /// An illustration of the usage of a defined term or phrase.
    public static let example = ContentRole("example")

    /// Ancillary information, such as a citation or commentary, that
    /// provides additional context to a referenced passage of text.
    public static let footnote = ContentRole("footnote")

    /// A brief dictionary of new, uncommon, or specialized terms used in
    /// the content.
    public static let glossary = ContentRole("glossary")

    /// A reference to a glossary definition.
    public static let glossref = ContentRole("glossref")

    /// A navigational aid that provides a detailed list of links to key
    /// subjects, names and other important topics covered in the work.
    public static let index = ContentRole("index")

    /// A preliminary section that typically introduces the scope or nature
    /// of the work.
    public static let introduction = ContentRole("introduction")

    /// A reference to a footnote or endnote, typically appearing as a
    /// superscripted number or symbol in the main body of text.
    public static let noteref = ContentRole("noteref")

    /// Notifies the user of consequences that might arise from an action
    /// or event. Examples include warnings, cautions and dangers.
    public static let notice = ContentRole("notice")

    /// A separator denoting the position before which a break occurs
    /// between two contiguous pages in a statically paginated version of
    /// the content.
    public static let pagebreak = ContentRole("pagebreak")

    /// A navigational aid that provides a list of links to the pagebreaks
    /// in the content.
    public static let pagelist = ContentRole("pagelist")

    /// A major structural division in a work that contains a set of
    /// related sections dealing with a particular subject, narrative arc or
    /// similar encapsulated theme.
    public static let part = ContentRole("part")

    /// An introductory section that precedes the work, typically written by
    /// the author of the work.
    public static let preface = ContentRole("preface")

    /// An introductory section that sets the background to a work,
    /// typically part of the narrative.
    public static let prologue = ContentRole("prologue")

    /// A distinctively placed or highlighted quotation from the current
    /// content designed to draw attention to a topic or highlight a key
    /// point.
    public static let pullquote = ContentRole("pullquote")

    /// A section of content structured as a series of questions and
    /// answers, such as an interview or list of frequently asked questions.
    public static let qna = ContentRole("qna")

    /// An explanatory or alternate title for the work, or a section or
    /// component within it.
    public static let subtitle = ContentRole("subtitle")

    /// Helpful information that clarifies some aspect of the content or
    /// assists in its comprehension.
    public static let tip = ContentRole("tip")

    /// A navigational aid that provides an ordered list of links to the
    /// major sectional headings in the content.
    public static let toc = ContentRole("toc")

    // MARK: Inherited from HTML and/or ARIA

    /// A self-contained composition in a document, page, application, or
    /// site, which is intended to be independently distributable or
    /// reusable.
    public static let article = ContentRole("article")

    /// Secondary or supplementary content.
    public static let aside = ContentRole("aside")

    /// Embedded sound content in a document.
    public static let audio = ContentRole("audio")

    /// A section that is quoted from another source.
    public static let blockquote = ContentRole("blockquote")

    /// Represents the content of an HTML document.
    public static let body = ContentRole("body")

    /// A caption for an image or a table.
    public static let caption = ContentRole("caption")

    /// A single cell of tabular data or content.
    public static let cell = ContentRole("cell")

    /// The header cell for a column, establishing a relationship between
    /// it and the other cells in the same column.
    public static let columnheader = ContentRole("columnheader")

    /// A supporting section of the document, designed to be complementary
    /// to the main content at a similar level in the DOM hierarchy.
    public static let complementary = ContentRole("complementary")

    /// A definition of a term or concept.
    public static let definition = ContentRole("definition")

    /// A disclosure widget that can be expanded.
    public static let details = ContentRole("details")

    /// An illustration, diagram, photo, code listing or similar,
    /// referenced from the text of a work, and typically annotated with a
    /// title, caption and/or credits.
    public static let figure = ContentRole("figure")

    /// Introductory content, typically a group of introductory or
    /// navigational aids.
    public static let header = ContentRole("header")

    /// A heading for a section of the page.
    public static let heading1 = ContentRole("heading1")

    /// A heading for a section of the page.
    public static let heading2 = ContentRole("heading2")

    /// A heading for a section of the page.
    public static let heading3 = ContentRole("heading3")

    /// A heading for a section of the page.
    public static let heading4 = ContentRole("heading4")

    /// A heading for a section of the page.
    public static let heading5 = ContentRole("heading5")

    /// A heading for a section of the page.
    public static let heading6 = ContentRole("heading6")

    /// An image.
    public static let image = ContentRole("image")

    /// A structure that contains an enumeration of related content items.
    public static let list = ContentRole("list")

    /// A single item in an enumeration.
    public static let listItem = ContentRole("listItem")

    /// Content that is directly related to or expands upon the central
    /// topic of the document.
    public static let main = ContentRole("main")

    /// Content that represents a mathematical expression.
    public static let math = ContentRole("math")

    /// A section of a page that links to other pages or to parts within
    /// the page.
    public static let navigation = ContentRole("navigation")

    /// A paragraph.
    public static let paragraph = ContentRole("paragraph")

    /// Preformatted text which is to be presented exactly as written.
    public static let preformatted = ContentRole("preformatted")

    /// An element being used only for presentation and therefore that does
    /// not have any accessibility semantics.
    public static let presentation = ContentRole("presentation")

    /// Content that is relevant to a specific, author-specified purpose
    /// and sufficiently important that users will likely want to be able to
    /// navigate to the section easily.
    public static let region = ContentRole("region")

    /// A row of data or content in a tabular structure.
    public static let row = ContentRole("row")

    /// The header cell for a row, establishing a relationship between it
    /// and the other cells in the same row.
    public static let rowheader = ContentRole("rowheader")

    /// A generic standalone section of a document, which doesn't have a
    /// more specific semantic element to represent it.
    public static let section = ContentRole("section")

    /// A divider that separates and distinguishes sections of content or
    /// groups of menu items.
    public static let separator = ContentRole("separator")

    /// A summary of an element contained in details.
    public static let summary = ContentRole("summary")

    /// A structure containing data or content laid out in tabular form.
    public static let table = ContentRole("table")

    /// A word or phrase with a corresponding definition.
    public static let term = ContentRole("term")

    /// Embedded videos, movies, or audio files with captions in a
    /// document.
    public static let video = ContentRole("video")

    // MARK: Inherited from EPUB SSV 1.1

    /// An area in a comic panel that contains the words, spoken or thought,
    /// of a character.
    public static let bubble = ContentRole("bubble")

    /// An introductory section that precedes the work, typically not
    /// written by the author of the work.
    public static let foreword = ContentRole("foreword")

    /// A collection of references to audio clips.
    public static let landmarks = ContentRole("landmarks")

    /// A listing of audio clips included in the work.
    public static let loa = ContentRole("loa")

    /// A listing of illustrations included in the work.
    public static let loi = ContentRole("loi")

    /// A listing of tables included in the work.
    public static let lot = ContentRole("lot")

    /// A listing of video clips included in the work.
    public static let lov = ContentRole("lov")

    /// An individual frame, or drawing.
    public static let panel = ContentRole("panel")

    /// A group of panels (e.g., a strip).
    public static let panelGroup = ContentRole("panelGroup")

    /// An area of text in a comic panel that represents a sound.
    public static let sound = ContentRole("sound")
}
