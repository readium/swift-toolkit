//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

struct XMLTester {
    let _make: (String, [XMLNamespace]) throws -> XMLDocument

    private let doc1 = """
    <?xml version="1.0" encoding="UTF-8"?>
    <menu>
      <food id="a">
        <name>Belgian Waffles</name>
      </food>
      <food id="b">
        <name>French Toast</name>
      </food>
      <food id="c">
        <name>Homestyle Breakfast</name>
      </food>
    </menu>
    """

    private func make(_ content: String, namespaces: [XMLNamespace] = []) throws -> XMLDocument {
        try _make(content, namespaces)
    }

    func testParseInvalidXML() {
        XCTAssertThrowsError(try make("Not an XML document"))
    }

    func testParseValidXML() {
        XCTAssertNoThrow(try make("""
        <?xml version="1.0" encoding="UTF-8"?>
        <root></root>
        """))
    }

    func testParseHTML5() {
        XCTAssertNoThrow(try make("""
        <!DOCTYPE html>
        <html lang='en'>
         <head></head>
         <body></body>
        </html>
        """))
    }

    func testDocumentElement() throws {
        let document = try make(doc1)
        XCTAssertEqual(
            document.documentElement?.localName,
            "menu"
        )
    }

    func testFirstElement() throws {
        let document = try make(doc1)
        XCTAssertEqual(
            document.first("/menu/food")?.attribute(named: "id"),
            "a"
        )
    }

    func testAllElements() throws {
        let document = try make(doc1)
        XCTAssertEqual(
            document.all("/menu/food").map { $0.attribute(named: "id") },
            ["a", "b", "c"]
        )
    }

    func testLocalName() throws {
        let document = try make(doc1)
        XCTAssertEqual(
            document.first("/menu/food")?.localName,
            "food"
        )
    }

    func testAttribute() throws {
        let document = try make(doc1)
        XCTAssertEqual(
            document.first("/menu/food")?.attribute(named: "id"),
            "a"
        )
    }
}

class FuziTests: XCTestCase {
    lazy var tester = XMLTester { xml, namespaces in
        try FuziXMLDocument(string: xml, namespaces: namespaces)
    }

    func testParseInvalidXML() { tester.testParseValidXML() }
    func testParseValidXML() { tester.testParseValidXML() }
    func testParseHTML5() { tester.testParseHTML5() }
    func testDocumentElement() throws { try tester.testDocumentElement() }
    func testFirstElement() throws { try tester.testFirstElement() }
    func testAllElements() throws { try tester.testAllElements() }
    func testLocalName() throws { try tester.testLocalName() }
    func testAttribute() throws { try tester.testAttribute() }
}
