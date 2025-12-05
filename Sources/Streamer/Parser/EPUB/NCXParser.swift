//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

/// From IDPF a11y-guidelines content/nav/toc.html :
/// "The NCX file is allowed for forwards compatibility purposes only. An EPUB 2
/// reading systems may open an EPUB 3 publication, but it will not be able to
/// use the new navigation document format.
/// You can ignore the NCX file if your book won't render properly as EPUB 2
/// content, or if you aren't targeting cross-compatibility."
final class NCXParser {
    enum NavType: String {
        case tableOfContents = "navMap"
        case pageList
    }

    private let data: Data
    private let url: RelativeURL

    /// Builds the NCX parser from the NCX data and its path. The path is used to normalize the links' hrefs.
    init(data: Data, at url: RelativeURL) {
        self.data = data
        self.url = url
    }

    private lazy var document: ReadiumFuzi.XMLDocument? = {
        let document = try? XMLDocument(data: data)
        document?.defineNamespace(.ncx)
        return document
    }()

    /// Returns the [Link] representation of the navigation list of given type (eg. pageList).
    func links(for type: NavType) -> [Link] {
        let nodeTagName: String = {
            if case .pageList = type {
                return "pageTarget"
            } else {
                return "navPoint"
            }
        }()

        guard let document = document,
              let nav = document.firstChild(xpath: "/ncx:ncx/ncx:\(type.rawValue)")
        else {
            return []
        }

        return links(in: nav, nodeTagName: nodeTagName)
    }

    /// Parses recursively a list of nodes as a list of `Link`.
    private func links(in element: ReadiumFuzi.XMLElement, nodeTagName: String) -> [Link] {
        element.xpath("ncx:\(nodeTagName)")
            .compactMap { self.link(for: $0, nodeTagName: nodeTagName) }
    }

    /// Parses a node element as a `Link`.
    private func link(for element: ReadiumFuzi.XMLElement, nodeTagName: String) -> Link? {
        NavigationDocumentParser.makeLink(
            title: element.firstChild(xpath: "ncx:navLabel/ncx:text")?.stringValue,
            href: element.firstChild(xpath: "ncx:content")?.attr("src").flatMap(RelativeURL.init(epubHREF:)),
            rel: nil,
            children: links(in: element, nodeTagName: nodeTagName),
            baseURL: url
        )
    }
}
