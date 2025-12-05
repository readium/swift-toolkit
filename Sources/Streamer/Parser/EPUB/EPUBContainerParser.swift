//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

/// A parser for the META-INF/container.xml file.
final class EPUBContainerParser: Loggable {
    private let document: ReadiumFuzi.XMLDocument

    init(data: Data) throws {
        document = try XMLDocument(data: data)
        document.defineNamespace(.cn)
    }

    convenience init(container: Container) async throws {
        let href = "META-INF/container.xml"
        guard let data = try? await container.readData(at: AnyURL(string: href)!) else {
            throw EPUBParserError.missingFile(path: href)
        }
        try self.init(data: data)
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
