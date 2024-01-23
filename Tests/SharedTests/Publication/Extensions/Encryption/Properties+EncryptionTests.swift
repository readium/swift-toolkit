//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

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
