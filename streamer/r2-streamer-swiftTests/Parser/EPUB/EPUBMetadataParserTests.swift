//
//  EPUBMetadataParserTests.swift
//  R2StreamerTests
//
//  Created by Mickaël Menu on 29.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import AEXML
import XCTest
import R2Shared
@testable import R2Streamer


class EPUBMetadataParserTests: XCTestCase {

    
    // MARK: - Toolkit
    
    func parseMetadata(_ name: String, displayOptions: String? = nil, epubVersion: Double) -> EPUBMetadataParser {
        func document(named name: String, type: String) -> AEXMLDocument {
            return try! AEXMLDocument(xml: try! Data(
                contentsOf: SampleGenerator().getSamplesFileURL(named: "OPF/\(name)", ofType: type)!
            ))
        }
        return EPUBMetadataParser(
            document: document(named: name, type: "opf"),
            displayOptions: displayOptions.map { document(named: $0, type: "xml") },
            epubVersion: epubVersion
        )
    }
    
}
