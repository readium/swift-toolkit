//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest

extension XCUIApplication {
    /// Opens a publication fixture.
    @discardableResult
    func open(_ fixture: PublicationFixture, waitUntilReady: Bool = true) -> ReaderUI {
        staticTexts[fixture.accessibilityIdentifier].firstMatch.tap()

        let reader = ReaderUI(app: self)

        if waitUntilReady {
            // Give the navigator time to fully load content.
            reader.assertReady()
        }

        return reader
    }

    /// Checks that some memory is allocated in the app.
    @discardableResult
    func assertSomeMemoryAllocated() -> Self {
        switches[.allMemoryDeallocated].assertIs(false)
        return self
    }

    /// Checks that all the tracked memory is deallocated in the app.
    ///
    /// A timeout is used to make sure the memory is cleared.
    @discardableResult
    func assertAllMemoryDeallocated() -> Self {
        switches[.allMemoryDeallocated].assertIs(true, waitForTimeout: 30)
        return self
    }
}

struct ReaderUI {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    /// Activates the Close button.
    @discardableResult
    func close(assertMemoryDeallocated: Bool = true) -> XCUIApplication {
        app.buttons[.close].tap()
        if assertMemoryDeallocated {
            app.assertAllMemoryDeallocated()
        }
        return app
    }

    /// Waits for the navigator to be ready.
    @discardableResult
    func assertReady(timeout: TimeInterval = 30) -> Self {
        app.switches[.isNavigatorReady].assertIs(true, waitForTimeout: timeout)
        return self
    }
}
