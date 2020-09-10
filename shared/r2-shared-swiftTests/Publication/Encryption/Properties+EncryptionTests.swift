//
//  Properties+EncryptionTests.swift
//  r2-shared-swift
//
//  Created by Mickaël on 25/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PropertiesEncryptionTests: XCTestCase {

    func testNoEncryption() {
        XCTAssertNil(Properties().encryption)
    }
    
    func testEncryption() {
        XCTAssertEqual(
            Properties(["encrypted": ["algorithm": "http://algo"]]).encryption,
            Encryption(algorithm: "http://algo")
        )
    }

}
