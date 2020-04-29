//
//  EPUBContainerParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 03.06.19.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import Fuzi
import R2Shared


/// A parser for the META-INF/container.xml file.
final class EPUBContainerParser: Loggable {
    
    private let document: Fuzi.XMLDocument

    init(data: Data) throws {
        self.document = try XMLDocument(data: data)
        self.document.definePrefix("cn", forNamespace: "urn:oasis:names:tc:opendocument:xmlns:container")
    }
    
    convenience init(container: Container) throws {
        let path = "META-INF/container.xml"
        do {
            let data = try container.data(relativePath: path)
            try self.init(data: data)
        } catch {
            throw EPUBParserError.missingFile(path: path)
        }
    }
    
    /// Parses the container.xml file and retrieves the relative path to the OPF file (rootFilePath) (the default one for now, not handling multiple renditions).
    func parseRootFilePath() throws -> String {
        // Get the path of the OPF file, relative to the metadata.rootPath.
        guard let path = document.firstChild(xpath: "/cn:container/cn:rootfiles/cn:rootfile")?.attr("full-path") else {
            throw EPUBParserError.missingRootfile
        }
        return path
    }
    
}
