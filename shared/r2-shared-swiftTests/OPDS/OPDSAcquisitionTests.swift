//
//  OPDSAcquisitionTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 12.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class OPDSAcquisitionTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? OPDSAcquisition(json: [
                "type": "acquisition-type"
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
                            [ "type": "sub-sub1" ],
                            [ "type": "sub-sub2" ]
                        ]
                    ]
                ]
            ]),
            OPDSAcquisition(type: "acquisition-type", children: [
                OPDSAcquisition(type: "sub-acquisition", children: [
                    OPDSAcquisition(type: "sub-sub1"),
                    OPDSAcquisition(type: "sub-sub2")
                ])
            ])
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try OPDSAcquisition(json: ""))
    }
    
    func testParseJSONRequiresType() {
        XCTAssertThrowsError(try OPDSAcquisition(json: ["child": []]))
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            [OPDSAcquisition](json: [
                [ "type": "acq1" ],
                [ "type": "acq2" ]
            ]),
            [
                OPDSAcquisition(type: "acq1"),
                OPDSAcquisition(type: "acq2")
            ]
        )
    }
    
    func testParseJSONArrayIgnoresInvalidAcquisitions() {
        XCTAssertEqual(
            [OPDSAcquisition](json: [
                [ "type": "acq1" ],
                [ "invalid": "acq2" ]
            ]),
            [
                OPDSAcquisition(type: "acq1")
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
                "type": "acquisition-type"
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            OPDSAcquisition(type: "acquisition-type", children: [
                OPDSAcquisition(type: "sub-acquisition", children: [
                    OPDSAcquisition(type: "sub-sub1"),
                    OPDSAcquisition(type: "sub-sub2")
                ])
            ]).json,
            [
                "type": "acquisition-type",
                "child": [
                    [
                        "type": "sub-acquisition",
                        "child": [
                            [ "type": "sub-sub1" ],
                            [ "type": "sub-sub2" ]
                        ]
                    ]
                ]
            ]
        )
    }
    
    func testGetJSONArray() {
        AssertJSONEqual(
            [
                OPDSAcquisition(type: "acq1"),
                OPDSAcquisition(type: "acq2")
            ].json,
            [
                [ "type": "acq1" ],
                [ "type": "acq2" ]
            ]
        )
    }
    
}
