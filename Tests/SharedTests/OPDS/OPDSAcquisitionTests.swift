//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
                    ] as [String: Any],
                ],
            ] as [String: Any]),
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
        XCTAssertThrowsError(try OPDSAcquisition(json: ["child": [] as [Any]]))
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            [OPDSAcquisition](json: [
                ["type": "acq1"],
                ["type": "acq2"],
            ]),
            [
                OPDSAcquisition(type: "acq1"),
                OPDSAcquisition(type: "acq2"),
            ]
        )
    }

    func testParseJSONArrayIgnoresInvalidAcquisitions() {
        XCTAssertEqual(
            [OPDSAcquisition](json: [
                ["type": "acq1"],
                ["invalid": "acq2"],
            ]),
            [
                OPDSAcquisition(type: "acq1"),
            ]
        )
    }

    func testParseJSONArrayWhenNil() {
        XCTAssertEqual(
            [OPDSAcquisition](json: nil),
            []
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            OPDSAcquisition(type: "acquisition-type").json,
            [
                "type": "acquisition-type",
            ]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            OPDSAcquisition(type: "acquisition-type", children: [
                OPDSAcquisition(type: "sub-acquisition", children: [
                    OPDSAcquisition(type: "sub-sub1"),
                    OPDSAcquisition(type: "sub-sub2"),
                ]),
            ]).json,
            [
                "type": "acquisition-type",
                "child": [
                    [
                        "type": "sub-acquisition",
                        "child": [
                            ["type": "sub-sub1"],
                            ["type": "sub-sub2"],
                        ],
                    ] as [String: Any],
                ],
            ] as [String: Any]
        )
    }

    func testGetJSONArray() {
        AssertJSONEqual(
            [
                OPDSAcquisition(type: "acq1"),
                OPDSAcquisition(type: "acq2"),
            ].json,
            [
                ["type": "acq1"],
                ["type": "acq2"],
            ]
        )
    }
}
