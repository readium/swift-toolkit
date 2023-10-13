//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Fuzi
import R2Shared

/// The navigation document if documented here at Navigation
/// https://idpf.github.io/a11y-guidelines/
/// http://www.idpf.org/epub/301/spec/epub-contentdocs.html#sec-xhtml-nav-def
final class NavigationDocumentParser {
    enum NavType: String {
        case tableOfContents = "toc"
        case pageList = "page-list"
        case landmarks
        case listOfIllustrations = "loi"
        case listOfTables = "lot"
        case listOfAudiofiles = "loa"
        case listOfVideos = "lov"
    }

    private let data: Data
    private let uri: URI

    /// Builds the navigation document parser from Navigation Document data and its path. The path is used to normalize the links' hrefs.
    init(data: Data, at uri: URI) {
        self.data = data
        self.uri = uri
    }

    private lazy var document: Fuzi.XMLDocument? = {
        // Warning: Somehow if we use HTMLDocument instead of XMLDocument, then the `epub` prefix doesn't work.
        let document = try? Fuzi.XMLDocument(data: data)
        document?.definePrefix("html", forNamespace: "http://www.w3.org/1999/xhtml")
        document?.definePrefix("epub", forNamespace: "http://www.idpf.org/2007/ops")
        return document
    }()

    /// Returns the [Link] representation of the navigation list of given type (eg. pageList).
    /// - Parameter type: epub:type of the <nav> element to parse.
    func links(for type: NavType) -> [Link] {
        guard let document = document,
              let nav = document.firstChild(xpath: "//html:nav[@epub:type='\(type.rawValue)']")
        else {
            return []
        }

        return links(in: nav)
    }

    /// Parses recursively an <ol> as a list of `Link`.
    private func links(in element: Fuzi.XMLElement) -> [Link] {
        element.xpath("html:ol[1]/html:li")
            .compactMap { self.link(for: $0) }
    }

    /// Parses a <li> element as a `Link`.
    private func link(for li: Fuzi.XMLElement) -> Link? {
        guard let label = li.firstChild(xpath: "html:a|html:span") else {
            return nil
        }

        return NavigationDocumentParser.makeLink(
            title: label.stringValue,
            href: label.attr("href").flatMap(URI.init(epubHREF:)),
            children: links(in: li),
            baseURI: uri
        )
    }

    /// Creates a new navigation `Link` object from a label, href and children, after validating the data.
    static func makeLink(title: String?, href: URI?, children: [Link], baseURI: URI) -> Link? {
        // Cleans up title label.
        // http://www.idpf.org/epub/301/spec/epub-contentdocs.html#confreq-nav-a-cnt
        let title = (title ?? "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let href = href.flatMap { baseURI.resolve($0) }

        guard
            // A zero-length text label must be ignored
            // http://www.idpf.org/epub/301/spec/epub-contentdocs.html#confreq-nav-a-cnt
            !title.isEmpty,
            // An unlinked item (`span`) without children must be ignored
            // http://www.idpf.org/epub/301/spec/epub-contentdocs.html#confreq-nav-a-nest
            href != nil || !children.isEmpty
        else {
            return nil
        }

        return Link(href: href?.string ?? "#", title: title, children: children)
    }
}
