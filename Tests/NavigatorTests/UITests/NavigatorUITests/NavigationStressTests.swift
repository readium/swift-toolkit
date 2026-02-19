//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest

final class NavigationStressTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// Rapidly navigates to random positions in an EPUB to trigger many
    /// concurrent resource loads and cancellations. If the app crashes, XCTest
    /// reports the failure automatically.
    ///
    /// Stress tests verifying that rapid navigation does not crash the app due to
    /// `WKURLSchemeTask` cancellation races.
    /// See https://github.com/readium/r2-navigator-swift/pull/160
    func testRapidNavigationDoesNotCrashOnEPUB() {
        let reader = app.open(.childrensLiteratureEPUB, waitUntilReady: true)

        app.buttons[.runStressTest].tap()
        app.switches[.stressTestCompleted].assertIs(true, waitForTimeout: 120)

        reader.close(assertMemoryDeallocated: true)
    }
}
