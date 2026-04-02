//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class OPDSAcquisitionTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? OPDSAcquisition(json: [
                "type": "acquisition-type",
            ]),
            OPDSAcquisition(type: "acquisition-type")
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? OPDSAcquisition(json: [
                "type": "acquisition-type",
                "child": [
                    [
                        "type": "sub-acquisition",
                        "child": [
                            ["type": "sub-sub1"],
                            ["type": "sub-sub2"],
                        ],
                    ],
                ],
            ] as JSONValue),
            OPDSAcquisition(type: "acquisition-type", children: [
                OPDSAcquisition(type: "sub-acquisition", children: [
                    OPDSAcquisition(type: "sub-sub1"),
                    OPDSAcquisition(type: "sub-sub2"),
                ]),
            ])
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try OPDSAcquisition(json: ""))
    }

    func testParseJSONRequiresType() {
        XCTAssertThrowsError(try OPDSAcquisition(json: ["child": [] as JSONValue]))
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            OPDSAcquisition(type: "acquisition-type").jsonObject,
            [
                "type": "acquisition-type",
            ]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            OPDSAcquisition(type: "acquisition-type", children: [
                OPDSAcquisition(type: "sub-acquisition", children: [
                    OPDSAcquisition(type: "sub-sub1"),
                    OPDSAcquisition(type: "sub-sub2"),
                ]),
            ]).jsonObject,
            [
                "type": "acquisition-type",
                "child": [
                    [
                        "type": "sub-acquisition",
                        "child": [
                            ["type": "sub-sub1"],
                            ["type": "sub-sub2"],
                        ],
                    ],
                ],
            ] as [String: JSONValue]
        )
    }
}
