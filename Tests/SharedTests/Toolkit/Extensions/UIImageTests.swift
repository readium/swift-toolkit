//
//  UIImageTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 12/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class UIImageTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Toolkit/Extensions")
    var image: UIImage!
    
    override func setUpWithError() throws {
        image = UIImage(contentsOfFile: fixtures.url(for: "image.jpg").path)!
    }

    func testScaleToFitReturnsBitmapWhenSizeMatches() {
        XCTAssertEqual(image.scaleToFit(maxSize: image.size), image)
    }

    func testScaleToFitReturnsBitmapWhenSizeIsBigger() {
        XCTAssertEqual(image.scaleToFit(maxSize: CGSize(width: 1000, height: 800)), image)
        XCTAssertEqual(image.scaleToFit(maxSize: CGSize(width: 598, height: 1000)), image)
        XCTAssertEqual(image.scaleToFit(maxSize: CGSize(width: 1000, height: 1000)), image)
    }

    func testScaleToFitScalesDownFittingHeight() {
        let size = image.scaleToFit(maxSize: CGSize(width: 300, height: 400)).size
        XCTAssertEqual(size, CGSize(width: 299, height: 400))
    }

    func testScaleToFitScalesDownFittingWidth() {
        let size = image.scaleToFit(maxSize: CGSize(width: 399, height: 800)).size
        XCTAssertEqual(size, CGSize(width: 399, height: 534))
    }

}
