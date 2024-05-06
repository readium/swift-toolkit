//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Fuzi
import ReadiumShared

/// A parser for the META-INF/container.xml file.
final class EPUBContainerParser: Loggable {
    private let document: Fuzi.XMLDocument

    init(data: Data) throws {
        document = try XMLDocument(data: data)
        document.definePrefix("cn", forNamespace: "urn:oasis:names:tc:opendocument:xmlns:container")
    }

    convenience init(fetcher: Fetcher) throws {
        let href = "META-INF/container.xml"
        do {
            let data = try fetcher.readData(at: AnyURL(string: href)!)
            try self.init(data: data)
        } catch {
            throw EPUBParserError.missingFile(path: href)
        }
    }

    /// Parses the container.xml file and retrieves the relative path to the OPF file (rootFilePath)
    /// (the default one for now, not handling multiple renditions).
    func parseOPFHREF() throws -> RelativeURL {
        // Get the path of the OPF file, relative to the metadata.rootPath.
        guard let uri = document
            .firstChild(xpath: "/cn:container/cn:rootfiles/cn:rootfile")?
            .attr("full-path")
            .flatMap(RelativeURL.init(epubHREF:))
        else {
            throw EPUBParserError.missingRootfile
        }
        return uri
    }
}
