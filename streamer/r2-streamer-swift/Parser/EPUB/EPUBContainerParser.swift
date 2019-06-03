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
    
    private let data: Data

    init(data: Data) {
        self.data = data
    }
    
    convenience init(container: Container) throws {
        let path = "META-INF/container.xml"
        do {
            let data = try container.data(relativePath: path)
            self.init(data: data)
        } catch {
            throw EpubParserError.missingFile(path: path)
        }
    }
    
    private lazy var document: XMLDocument? = {
        let document = try? XMLDocument(data: data)
        document?.definePrefix("cn", forNamespace: "urn:oasis:names:tc:opendocument:xmlns:container")
        return document
    }()
    
    /// Parses the container.xml file and retrieves the relative path to the OPF file (rootFilePath) (the default one for now, not handling multiple renditions).
    func parseRootFilePath() throws -> String {
        // Get the path of the OPF file, relative to the metadata.rootPath.
        guard let document = document,
            let opfFilePath = document.firstChild(xpath: "/cn:container/cn:rootfiles/cn:rootfile")?.attr("full-path") else
        {
            throw EpubParserError.missingElement(message: "Missing rootfile in `container.xml`.")
        }
        return opfFilePath
    }
    
}
