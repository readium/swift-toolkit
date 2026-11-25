//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct CSSRSPropertiesTests {
    @Test func convertEmptyPropertiesToCSSProperties() {
        #expect(
            CSSRSProperties().cssProperties() == [
                "--RS__disableOverflow": nil,
            ]
        )
    }

    @Test func convertFullPropertiesToCSSProperties() {
        #expect(
            CSSRSProperties(
                noOverflow: true
            ).cssProperties() == [
                "--RS__disableOverflow": "readium-noOverflow-on",
            ]
        )
    }

    @Test func disabledFlagsAreNotEmitted() {
        #expect(CSSRSProperties(noOverflow: false).css() == nil)
    }
}
